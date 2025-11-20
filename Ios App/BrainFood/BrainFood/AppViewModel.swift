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

    private let api = APIService.shared
    private let fsrs = FSRSCalculator()

    var dueCards: [Card] {
        let now = Date()
        return cards.filter { $0.due <= now }.sorted { $0.due < $1.due }
    }

    func loadCards(dueOnly: Bool = false) async {
        isLoading = true
        error = nil
        do {
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
}
