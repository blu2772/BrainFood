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
                // Nutze suggestedCards statt allCards, da live erkannte Karten bereits dort sind
                let finalCount = self.suggestedCards.count
                currentStatus = "✓ Fertig! \(finalCount) Karten erstellt"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Stelle sicher, dass alle Karten ausgewählt sind
                    self.selectedCards = Set(self.suggestedCards.map { $0.id })
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
                        // Füge finale Karten hinzu (falls noch nicht durch Live-Parsing erkannt)
                        for card in cards {
                            if !self.suggestedCards.contains(where: { $0.front == card.front && $0.back == card.back }) {
                                self.suggestedCards.append(card)
                                self.selectedCards.insert(card.id)
                            }
                        }
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
                        // Füge finale Karten hinzu (falls noch nicht durch Live-Parsing erkannt)
                        for card in cards {
                            if !self.suggestedCards.contains(where: { $0.front == card.front && $0.back == card.back }) {
                                self.suggestedCards.append(card)
                                self.selectedCards.insert(card.id)
                            }
                        }
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
                    print("📨 [AICardsViewModel] Event empfangen (Text): type=\(event.type), message=\(event.message.prefix(100))")
                    
                    switch event.type {
                    case "status":
                        self.currentStatus = event.message
                        print("   📊 Status: \(event.message)")
                        // Aktualisiere Kartenanzahl wenn in Status-Meldung enthalten
                        if event.message.contains("Karten") || event.message.contains("Karte") {
                            // Extrahiere Zahl aus Status-Meldung falls vorhanden
                            let components = event.message.components(separatedBy: CharacterSet.decimalDigits.inverted)
                            if let numberString = components.first(where: { !$0.isEmpty }),
                               let number = Int(numberString) {
                                self.cardsCreatedCount = number
                                print("   🔢 Kartenanzahl aktualisiert: \(number)")
                            }
                        }
                    case "content":
                        // Prüfe ob partialCards vorhanden sind (live erkannte Karten)
                        if let partialCards = event.data?.partialCards as? [[String: Any]] {
                            // Konvertiere zu CardSuggestion
                            let newCards = partialCards.compactMap { dict -> CardSuggestion? in
                                guard let front = dict["front"] as? String,
                                      let back = dict["back"] as? String else {
                                    return nil
                                }
                                let tags = dict["tags"] as? String
                                return CardSuggestion(front: front, back: back, tags: tags)
                            }
                            
                            // Füge neue Karten hinzu (nur wenn noch nicht vorhanden)
                            for card in newCards {
                                if !self.suggestedCards.contains(where: { $0.front == card.front && $0.back == card.back }) {
                                    self.suggestedCards.append(card)
                                    self.selectedCards.insert(card.id)
                                }
                            }
                            
                            self.cardsCreatedCount = self.suggestedCards.count
                            self.currentStatus = "KI generiert... (\(self.cardsCreatedCount) Karte\(self.cardsCreatedCount == 1 ? "" : "n") erkannt)"
                            print("   📦 Live: \(newCards.count) neue Karten erkannt, Gesamt: \(self.cardsCreatedCount)")
                        } else if let partial = event.data?.partial {
                            self.currentStatus = "KI schreibt: \(partial.prefix(50))..."
                            print("   ✍️ Content: \(partial.prefix(100))...")
                        }
                    case "done":
                        print("🟢 [AICardsViewModel] 'done' Event empfangen (Text)")
                        if let cards = event.data?.cards {
                            print("   📦 \(cards.count) Karten im Event")
                            
                            // Validiere und filtere ungültige Karten
                            let validCards = cards.filter { card in
                                let isValid = !card.front.trimmingCharacters(in: .whitespaces).isEmpty &&
                                            !card.back.trimmingCharacters(in: .whitespaces).isEmpty
                                if !isValid {
                                    print("   ⚠️ Ungültige Karte gefiltert: front='\(card.front.prefix(30))...' back='\(card.back.prefix(30))...'")
                                }
                                return isValid
                            }
                            print("   ✅ \(validCards.count) gültige Karten nach Validierung")
                            self.cardsCreatedCount += validCards.count
                            completion(validCards)
                        } else {
                            print("   ⚠️ Keine Karten im 'done' Event")
                            completion([])
                        }
                    case "error":
                        print("❌ [AICardsViewModel] Error Event (Text):")
                        print("   Message: \(event.message)")
                        if let errorData = event.data?.error {
                            print("   Error Data: \(errorData)")
                        }
                        if let rawContent = event.data?.rawContent {
                            print("   Raw Content (erste 500 Zeichen):")
                            print("   \(rawContent.prefix(500))")
                        }
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
                    print("❌ [AICardsViewModel] Network Error (Text): \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.currentStatus = "❌ Fehler: \(error.localizedDescription)"
                    completion([])
                }
            }
        )
    }
    
    private func processPDFSource(pdfData: Data, completion: @escaping ([CardSuggestion]) -> Void) {
        print("🚀 [AICardsViewModel] Starte PDF-Verarbeitung (Größe: \(pdfData.count) bytes)")
        apiClient.suggestCardsStream(
            boxId: boxId,
            goal: goal.isEmpty ? nil : goal,
            text: nil,
            pdfData: pdfData,
            onEvent: { [weak self] event in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    print("📨 [AICardsViewModel] Event empfangen (PDF): type=\(event.type), message=\(event.message.prefix(100))")
                    
                    switch event.type {
                    case "status":
                        self.currentStatus = event.message
                        print("   📊 Status: \(event.message)")
                        // Aktualisiere Kartenanzahl wenn in Status-Meldung enthalten
                        if event.message.contains("Karten") || event.message.contains("Karte") {
                            // Extrahiere Zahl aus Status-Meldung falls vorhanden
                            let components = event.message.components(separatedBy: CharacterSet.decimalDigits.inverted)
                            if let numberString = components.first(where: { !$0.isEmpty }),
                               let number = Int(numberString) {
                                self.cardsCreatedCount = number
                                print("   🔢 Kartenanzahl aktualisiert: \(number)")
                            }
                        }
                    case "content":
                        // Prüfe ob partialCards vorhanden sind (live erkannte Karten)
                        if let partialCards = event.data?.partialCards as? [[String: Any]] {
                            // Konvertiere zu CardSuggestion
                            let newCards = partialCards.compactMap { dict -> CardSuggestion? in
                                guard let front = dict["front"] as? String,
                                      let back = dict["back"] as? String else {
                                    return nil
                                }
                                let tags = dict["tags"] as? String
                                return CardSuggestion(front: front, back: back, tags: tags)
                            }
                            
                            // Füge neue Karten hinzu (nur wenn noch nicht vorhanden)
                            for card in newCards {
                                if !self.suggestedCards.contains(where: { $0.front == card.front && $0.back == card.back }) {
                                    self.suggestedCards.append(card)
                                    self.selectedCards.insert(card.id)
                                }
                            }
                            
                            self.cardsCreatedCount = self.suggestedCards.count
                            self.currentStatus = "KI generiert... (\(self.cardsCreatedCount) Karte\(self.cardsCreatedCount == 1 ? "" : "n") erkannt)"
                            print("   📦 Live: \(newCards.count) neue Karten erkannt, Gesamt: \(self.cardsCreatedCount)")
                        } else if let partial = event.data?.partial {
                            self.currentStatus = "KI schreibt: \(partial.prefix(50))..."
                            print("   ✍️ Content: \(partial.prefix(100))...")
                        }
                    case "done":
                        print("🟢 [AICardsViewModel] 'done' Event empfangen (PDF)")
                        if let cards = event.data?.cards {
                            print("   📦 \(cards.count) Karten im Event")
                            
                            // Validiere und filtere ungültige Karten
                            let validCards = cards.filter { card in
                                let isValid = !card.front.trimmingCharacters(in: .whitespaces).isEmpty &&
                                            !card.back.trimmingCharacters(in: .whitespaces).isEmpty
                                if !isValid {
                                    print("   ⚠️ Ungültige Karte gefiltert: front='\(card.front.prefix(30))...' back='\(card.back.prefix(30))...'")
                                }
                                return isValid
                            }
                            print("   ✅ \(validCards.count) gültige Karten nach Validierung")
                            self.cardsCreatedCount += validCards.count
                            completion(validCards)
                        } else {
                            print("   ⚠️ Keine Karten im 'done' Event")
                            completion([])
                        }
                    case "error":
                        print("❌ [AICardsViewModel] Error Event (PDF):")
                        print("   Message: \(event.message)")
                        if let errorData = event.data?.error {
                            print("   Error Data: \(errorData)")
                        }
                        if let rawContent = event.data?.rawContent {
                            print("   Raw Content (erste 500 Zeichen):")
                            print("   \(rawContent.prefix(500))")
                        }
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
                    print("❌ [AICardsViewModel] Network Error (PDF): \(error.localizedDescription)")
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

