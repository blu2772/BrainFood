//
//  LearningViewModel.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class LearningViewModel: ObservableObject {
    @Published var currentCard: Card?
    @Published var showAnswer = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var stats: BoxStats?
    
    private let apiClient = APIClient.shared
    private let boxId: String
    private var reviewQueue: [Card] = []
    
    init(boxId: String) {
        self.boxId = boxId
    }
    
    func loadStats() async {
        do {
            stats = try await apiClient.getStats(boxId: boxId)
        } catch {
            // Fehler ignorieren, Stats sind optional
        }
    }
    
    func loadNextCard() async {
        isLoading = true
        errorMessage = nil
        showAnswer = false
        
        // Wenn Queue leer, neue Karten laden
        if reviewQueue.isEmpty {
        do {
                reviewQueue = try await apiClient.getNextReviews(boxId: boxId, limit: 10)
            } catch let error as APIError {
                errorMessage = error.errorDescription
                currentCard = nil
                isLoading = false
                return
        } catch {
                errorMessage = "Fehler beim Laden der Karten"
                currentCard = nil
                isLoading = false
                return
            }
        }
        
        // Nächste Karte aus Queue nehmen
        if let nextCard = reviewQueue.first {
            currentCard = nextCard
            reviewQueue.removeFirst()
        } else {
            currentCard = nil
        }
        
        isLoading = false
    }
    
    func reviewCard(rating: String) async {
        guard let card = currentCard else { return }
        
        isLoading = true
        
        do {
            _ = try await apiClient.reviewCard(cardId: card.id, rating: rating)
            // Lade nächste Karte
            await loadNextCard()
            // Stats aktualisieren
            await loadStats()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Fehler beim Speichern der Bewertung"
        }
        
        isLoading = false
    }
}

