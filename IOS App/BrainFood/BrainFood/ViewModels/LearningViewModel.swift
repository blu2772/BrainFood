import Foundation
import SwiftUI

class LearningViewModel: ObservableObject {
    @Published var currentCard: Card?
    @Published var showAnswer = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var stats: BoxStats?
    
    private let apiClient = APIClient.shared
    let boxId: String
    
    init(boxId: String) {
        self.boxId = boxId
    }
    
    @MainActor
    func loadNextCard() async {
        isLoading = true
        errorMessage = nil
        showAnswer = false
        
        do {
            let cards = try await apiClient.getNextReviews(boxId: boxId, limit: 1)
            currentCard = cards.first
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func submitReview(rating: ReviewRating) async {
        guard let card = currentCard else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await apiClient.submitReview(cardId: card.id, rating: rating)
            await loadNextCard()
            await loadStats()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func loadStats() async {
        do {
            stats = try await apiClient.getBoxStats(boxId: boxId)
        } catch {
            // Stats loading failure is not critical
            print("Failed to load stats: \(error)")
        }
    }
}

