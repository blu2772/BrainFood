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
    @Published var currentStatus: String = ""
    @Published var processingProgress: Double = 0.0
    @Published var cardsCreatedCount: Int = 0 // Anzahl der erstellten Karten
    
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
    
    func addImageSource(_ data: Data, filename: String) {
        let source = SourceItem(type: .image, content: nil, data: data, filename: filename)
        selectedSources.append(source)
    }
    
    func removeSource(_ source: SourceItem) {
        selectedSources.removeAll { $0.id == source.id }
    }
    
    private var sseClient: SSEClient?
    
    private func processSources() {
        isProcessing = true
        errorMessage = nil
        currentStatus = "Starte Verarbeitung..."
        processingProgress = 0.0
        cardsCreatedCount = 0
        
        var allCards: [CardSuggestion] = []
        var processedSources = 0
        let totalSources = selectedSources.count
        
        // Verarbeite jede Quelle mit Streaming
        func processNextSource() {
            guard processedSources < totalSources else {
                // Alle Quellen verarbeitet
                processingProgress = 1.0
                currentStatus = "✓ Fertig! \(allCards.count) Karten erstellt"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.suggestedCards = allCards
                    self.selectedCards = Set(allCards.map { $0.id })
                    self.currentStep = .review
                    self.isProcessing = false
                }
                return
            }
            
            let source = selectedSources[processedSources]
            let progress = Double(processedSources) / Double(totalSources)
            processingProgress = progress
            
            switch source.type {
            case .text:
                if let text = source.content {
                    processTextSource(text: text) { cards in
                        allCards.append(contentsOf: cards)
                        processedSources += 1
                        processNextSource()
                    }
                } else {
                    processedSources += 1
                    processNextSource()
                }
            case .pdf:
                if let pdfData = source.data {
                    processPDFSource(pdfData: pdfData) { cards in
                        allCards.append(contentsOf: cards)
                        processedSources += 1
                        processNextSource()
                    }
                } else {
                    processedSources += 1
                    processNextSource()
                }
            case .image:
                currentStatus = "⚠ Bilder werden aktuell noch nicht unterstützt"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    processedSources += 1
                    processNextSource()
                }
            }
        }
        
        processNextSource()
    }
    
    private func processTextSource(text: String, completion: @escaping ([CardSuggestion]) -> Void) {
        apiClient.suggestCardsStream(
            boxId: boxId,
            goal: goal.isEmpty ? nil : goal,
            text: text,
            pdfData: nil,
            onEvent: { [weak self] event in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    switch event.type {
                    case "status":
                        self.currentStatus = event.message
                        // Aktualisiere Kartenanzahl wenn in Status-Meldung enthalten
                        if event.message.contains("Karten") || event.message.contains("Karte") {
                            // Extrahiere Zahl aus Status-Meldung falls vorhanden
                            let components = event.message.components(separatedBy: CharacterSet.decimalDigits.inverted)
                            if let numberString = components.first(where: { !$0.isEmpty }),
                               let number = Int(numberString) {
                                self.cardsCreatedCount = number
                            }
                        }
                    case "content":
                        if let partial = event.data?.partial {
                            self.currentStatus = "KI schreibt: \(partial.prefix(50))..."
                        }
                    case "done":
                        if let cards = event.data?.cards {
                            // Validiere und filtere ungültige Karten
                            let validCards = cards.filter { card in
                                guard !card.front.trimmingCharacters(in: .whitespaces).isEmpty,
                                      !card.back.trimmingCharacters(in: .whitespaces).isEmpty else {
                                    return false
                                }
                                return true
                            }
                            self.cardsCreatedCount += validCards.count
                            completion(validCards)
                        } else {
                            completion([])
                        }
                    case "error":
                        self.errorMessage = event.message
                        self.currentStatus = "❌ \(event.message)"
                        completion([])
                    default:
                        break
                    }
                }
            },
            onError: { [weak self] error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.currentStatus = "❌ Fehler: \(error.localizedDescription)"
                    completion([])
                }
            }
        )
    }
    
    private func processPDFSource(pdfData: Data, completion: @escaping ([CardSuggestion]) -> Void) {
        apiClient.suggestCardsStream(
            boxId: boxId,
            goal: goal.isEmpty ? nil : goal,
            text: nil,
            pdfData: pdfData,
            onEvent: { [weak self] event in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    switch event.type {
                    case "status":
                        self.currentStatus = event.message
                        // Aktualisiere Kartenanzahl wenn in Status-Meldung enthalten
                        if event.message.contains("Karten") || event.message.contains("Karte") {
                            // Extrahiere Zahl aus Status-Meldung falls vorhanden
                            let components = event.message.components(separatedBy: CharacterSet.decimalDigits.inverted)
                            if let numberString = components.first(where: { !$0.isEmpty }),
                               let number = Int(numberString) {
                                self.cardsCreatedCount = number
                            }
                        }
                    case "content":
                        if let partial = event.data?.partial {
                            self.currentStatus = "KI schreibt: \(partial.prefix(50))..."
                        }
                    case "done":
                        if let cards = event.data?.cards {
                            // Validiere und filtere ungültige Karten
                            let validCards = cards.filter { card in
                                guard !card.front.trimmingCharacters(in: .whitespaces).isEmpty,
                                      !card.back.trimmingCharacters(in: .whitespaces).isEmpty else {
                                    return false
                                }
                                return true
                            }
                            self.cardsCreatedCount += validCards.count
                            completion(validCards)
                        } else {
                            completion([])
                        }
                    case "error":
                        self.errorMessage = event.message
                        self.currentStatus = "❌ \(event.message)"
                        completion([])
                    default:
                        break
                    }
                }
            },
            onError: { [weak self] error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.currentStatus = "❌ Fehler: \(error.localizedDescription)"
                    completion([])
                }
            }
        )
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

