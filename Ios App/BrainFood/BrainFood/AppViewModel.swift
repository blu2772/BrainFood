import Foundation
import SwiftUI
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    // Explicit publisher keeps ObservableObject conformance obvious for the compiler.
    let objectWillChange = ObservableObjectPublisher()
    @Published var cards: [Card] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isShowingCreate = false
    @Published var userId: String?
    @Published var boxId: String?
    @Published var boxes: [Box] = []

    private let api = APIService.shared
    private let fsrs = FSRSCalculator()

    init() {
        self.userId = UserDefaults.standard.string(forKey: "brainfood_userId")
        self.boxId = UserDefaults.standard.string(forKey: "brainfood_boxId")
        api.userId = self.userId
        api.boxId = self.boxId
    }

    var dueCards: [Card] {
        let now = Date()
        return cards.filter { $0.due <= now }.sorted { $0.due < $1.due }
    }

    func loadCards(dueOnly: Bool = false) async {
        guard let userId, let boxId else {
            self.error = "Bitte zuerst Benutzer und Box festlegen."
            return
        }
        isLoading = true
        error = nil
        do {
            api.userId = userId
            api.boxId = boxId
            let fetched = try await api.fetchCards(dueOnly: dueOnly)
            withAnimation {
                cards = fetched
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func review(card: Card, rating: ReviewRating) async {
        do {
            // Optimistic update for a snappy UI
            let optimistic = fsrs.next(for: card, rating: rating)
            if let index = cards.firstIndex(where: { $0.id == card.id }) {
                cards[index] = optimistic
            }
            let updated = try await api.review(cardId: card.id, rating: rating)
            if let index = cards.firstIndex(where: { $0.id == card.id }) {
                withAnimation {
                    cards[index] = updated
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createCard(front: String, back: String, tags: [String]) async {
        do {
            let request = CreateCardPayload(front: front, back: back, tags: tags)
            let created = try await api.createCard(request: request)
            withAnimation {
                cards.append(created)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createUser(name: String) async {
        do {
            let user = try await api.createUser(name: name)
            self.userId = user.id
            api.userId = user.id
            UserDefaults.standard.set(user.id, forKey: "brainfood_userId")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createBox(name: String) async {
        guard let userId else {
            self.error = "Bitte zuerst Benutzer anlegen."
            return
        }
        do {
            let box = try await api.createBox(userId: userId, name: name)
            self.boxes.append(box)
            self.boxId = box.id
            api.boxId = box.id
            UserDefaults.standard.set(box.id, forKey: "brainfood_boxId")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadBoxes() async {
        guard let userId else { return }
        do {
            boxes = try await api.listBoxes(userId: userId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
