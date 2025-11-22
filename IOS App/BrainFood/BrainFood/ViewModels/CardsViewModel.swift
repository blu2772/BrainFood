import Foundation
import SwiftUI

@MainActor
class CardsViewModel: ObservableObject {
    @Published var cards: [Card] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    
    private let apiClient = APIClient.shared
    let boxId: String
    
    init(boxId: String) {
        self.boxId = boxId
    }
    
    var filteredCards: [Card] {
        if searchText.isEmpty {
            return cards
        }
        return cards.filter { card in
            card.front.localizedCaseInsensitiveContains(searchText) ||
            card.back.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    func loadCards() async {
        isLoading = true
        errorMessage = nil
        
        do {
            cards = try await apiClient.getCards(boxId: boxId, sort: "due")
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func createCard(front: String, back: String, tags: String?) async {
        do {
            let newCard = try await apiClient.createCard(boxId: boxId, front: front, back: back, tags: tags)
            cards.append(newCard)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateCard(_ card: Card, front: String?, back: String?, tags: String?) async {
        do {
            let updatedCard = try await apiClient.updateCard(cardId: card.id, front: front, back: back, tags: tags)
            if let index = cards.firstIndex(where: { $0.id == card.id }) {
                cards[index] = updatedCard
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteCard(_ card: Card) async {
        do {
            try await apiClient.deleteCard(cardId: card.id)
            cards.removeAll { $0.id == card.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

