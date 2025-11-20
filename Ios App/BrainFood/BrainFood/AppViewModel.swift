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
    @Published var token: String?

    private let api = APIService.shared
    private let fsrs = FSRSCalculator()

    init() {
        self.userId = UserDefaults.standard.string(forKey: "brainfood_userId")
        self.boxId = UserDefaults.standard.string(forKey: "brainfood_boxId")
        self.token = UserDefaults.standard.string(forKey: "brainfood_token")
        api.userId = self.userId
        api.boxId = self.boxId
        api.token = self.token
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
            self.error = translateError(error)
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
            self.error = translateError(error)
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
            self.error = translateError(error)
        }
    }

    func createUser(name: String) async {
        // Deprecated in favor of auth/register
        await register(name: name, email: "\(UUID().uuidString)@placeholder.local", password: UUID().uuidString)
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
            self.error = translateError(error)
        }
    }

    func loadBoxes() async {
        guard let userId else { return }
        do {
            boxes = try await api.listBoxes(userId: userId)
        } catch {
            self.error = translateError(error)
        }
    }

    func register(name: String, email: String, password: String) async {
        do {
            error = nil
            let auth = try await api.register(name: name, email: email, password: password)
            applyAuth(auth, userId: auth.user.id, boxId: nil)
            await loadBoxes()
        } catch {
            self.error = translateError(error)
        }
    }

    func login(email: String, password: String) async {
        do {
            error = nil
            let auth = try await api.login(email: email, password: password)
            applyAuth(auth, userId: auth.user.id, boxId: nil)
            await loadBoxes()
        } catch {
            self.error = translateError(error)
        }
    }

    func selectBox(_ box: Box) {
        self.boxId = box.id
        api.boxId = box.id
        UserDefaults.standard.set(box.id, forKey: "brainfood_boxId")
    }

    func logout() {
        userId = nil
        boxId = nil
        token = nil
        boxes = []
        cards = []
        api.userId = nil
        api.boxId = nil
        api.token = nil
        UserDefaults.standard.removeObject(forKey: "brainfood_userId")
        UserDefaults.standard.removeObject(forKey: "brainfood_boxId")
        UserDefaults.standard.removeObject(forKey: "brainfood_token")
    }

    private func applyAuth(_ auth: AuthResponse, userId: String, boxId: String?) {
        self.userId = userId
        self.token = auth.token
        api.userId = userId
        api.token = auth.token
        UserDefaults.standard.set(userId, forKey: "brainfood_userId")
        UserDefaults.standard.set(auth.token, forKey: "brainfood_token")
        if let boxId {
            self.boxId = boxId
            api.boxId = boxId
            UserDefaults.standard.set(boxId, forKey: "brainfood_boxId")
        }
    }
    
    private func translateError(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .server(let message):
                switch message {
                case "email_exists":
                    return "Diese E-Mail-Adresse ist bereits registriert."
                case "invalid_credentials":
                    return "E-Mail oder Passwort falsch."
                case "email_and_password_required", "name_email_password_required":
                    return "Bitte alle Felder ausfüllen."
                case "token_invalid_or_expired", "authentication_required":
                    return "Sitzung abgelaufen. Bitte erneut anmelden."
                case "forbidden":
                    return "Zugriff verweigert."
                default:
                    return message.replacingOccurrences(of: "_", with: " ").capitalized
                }
            case .invalidURL:
                return "Ungültige Server-URL."
            case .decoding:
                return "Antwort konnte nicht gelesen werden."
            case .unknown:
                return "Unerwarteter Fehler."
            }
        }
        return error.localizedDescription
    }
}
