//
//  CardsViewModel.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CardsViewModel: ObservableObject {
    @Published var cards: [Card] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = "" {
        didSet {
            filterCards()
        }
    }
    
    private let apiClient = APIClient.shared
    private let boxId: String
    
    var filteredCards: [Card] = []
    
    init(boxId: String) {
        self.boxId = boxId
    }
    
    func loadCards() async {
        isLoading = true
        errorMessage = nil
        
        do {
            cards = try await apiClient.getCards(boxId: boxId, sort: "due")
            filterCards()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Fehler beim Laden der Karten"
        }
        
        isLoading = false
    }
    
    func createCard(front: String, back: String, tags: String?) async {
        do {
            let newCard = try await apiClient.createCard(boxId: boxId, front: front, back: back, tags: tags)
            cards.append(newCard)
            filterCards()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Fehler beim Erstellen der Karte"
        }
    }
    
    func updateCard(cardId: String, front: String?, back: String?, tags: String?) async {
        do {
            let updatedCard = try await apiClient.updateCard(cardId: cardId, front: front, back: back, tags: tags)
            if let index = cards.firstIndex(where: { $0.id == cardId }) {
                cards[index] = updatedCard
            }
            filterCards()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Fehler beim Aktualisieren der Karte"
        }
    }
    
    func deleteCard(_ card: Card) async {
        do {
            try await apiClient.deleteCard(cardId: card.id)
            cards.removeAll { $0.id == card.id }
            filterCards()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Fehler beim Löschen der Karte"
        }
    }
    
    private func filterCards() {
        if searchText.isEmpty {
            filteredCards = cards
        } else {
            filteredCards = cards.filter { card in
                card.front.localizedCaseInsensitiveContains(searchText) ||
                card.back.localizedCaseInsensitiveContains(searchText) ||
                (card.tags?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
}

