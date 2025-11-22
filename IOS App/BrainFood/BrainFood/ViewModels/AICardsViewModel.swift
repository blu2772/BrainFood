//
//  AICardsViewModel.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import Foundation
import SwiftUI
import Combine
import PhotosUI

@MainActor
class AICardsViewModel: ObservableObject {
    @Published var currentStep: AICreationStep = .goal
    @Published var goal: String = ""
    @Published var selectedSources: [SourceItem] = []
    @Published var isProcessing = false
    @Published var suggestedCards: [CardSuggestion] = []
    @Published var selectedCards: Set<String> = []
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    let boxId: String
    
    init(boxId: String) {
        self.boxId = boxId
    }
    
    func nextStep() {
        switch currentStep {
        case .goal:
            if !goal.isEmpty {
                currentStep = .sources
            }
        case .sources:
            if !selectedSources.isEmpty {
                currentStep = .processing
                processSources()
            }
        case .processing:
            break
        case .review:
            break
        }
    }
    
    func previousStep() {
        switch currentStep {
        case .goal:
            break
        case .sources:
            currentStep = .goal
        case .processing:
            currentStep = .sources
        case .review:
            currentStep = .sources
        }
    }
    
    func addTextSource(_ text: String) {
        let source = SourceItem(type: .text, content: text)
        selectedSources.append(source)
    }
    
    func addPDFSource(_ data: Data, filename: String) {
        let source = SourceItem(type: .pdf, content: nil, data: data, filename: filename)
        selectedSources.append(source)
    }
    
    func removeSource(_ source: SourceItem) {
        selectedSources.removeAll { $0.id == source.id }
    }
    
    private func processSources() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                var allCards: [CardSuggestion] = []
                
                for source in selectedSources {
                    switch source.type {
                    case .text:
                        if let text = source.content {
                            let cards = try await apiClient.suggestCards(
                                boxId: boxId,
                                goal: goal.isEmpty ? nil : goal,
                                text: text,
                                pdfData: nil
                            )
                            allCards.append(contentsOf: cards)
                        }
                    case .pdf:
                        if let pdfData = source.data {
                            let cards = try await apiClient.suggestCards(
                                boxId: boxId,
                                goal: goal.isEmpty ? nil : goal,
                                text: nil,
                                pdfData: pdfData
                            )
                            allCards.append(contentsOf: cards)
                        }
                    }
                }
                
                suggestedCards = allCards
                selectedCards = Set(allCards.map { $0.id })
                currentStep = .review
            } catch let error as APIError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "Fehler beim Generieren der Karten"
            }
            
            isProcessing = false
        }
    }
    
    func toggleCardSelection(_ cardId: String) {
        if selectedCards.contains(cardId) {
            selectedCards.remove(cardId)
        } else {
            selectedCards.insert(cardId)
        }
    }
    
    func saveSelectedCards(cardsViewModel: CardsViewModel) async {
        let cardsToSave = suggestedCards.filter { selectedCards.contains($0.id) }
        
        for card in cardsToSave {
            await cardsViewModel.createCard(
                front: card.front,
                back: card.back,
                tags: card.tags
            )
        }
    }
}

enum AICreationStep {
    case goal
    case sources
    case processing
    case review
}

struct SourceItem: Identifiable {
    let id = UUID()
    let type: SourceType
    let content: String?
    let data: Data?
    let filename: String?
    
    init(type: SourceType, content: String? = nil, data: Data? = nil, filename: String? = nil) {
        self.type = type
        self.content = content
        self.data = data
        self.filename = filename
    }
}

enum SourceType {
    case text
    case pdf
    case image
}

