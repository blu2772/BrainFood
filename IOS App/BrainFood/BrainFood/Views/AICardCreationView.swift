//
//  AICardCreationView.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import SwiftUI
import PhotosUI

struct AICardCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AICardsViewModel
    @ObservedObject var cardsViewModel: CardsViewModel
    @State private var textInput = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPDF: URL?
    
    var body: some View {
        NavigationStack {
            ZStack {
                switch viewModel.currentStep {
                case .goal:
                    GoalStepView(viewModel: viewModel)
                case .sources:
                    SourcesStepView(
                        viewModel: viewModel,
                        textInput: $textInput,
                        selectedPhoto: $selectedPhoto,
                        selectedPDF: $selectedPDF
                    )
                case .processing:
                    ProcessingStepView(viewModel: viewModel)
                case .review:
                    ReviewStepView(viewModel: viewModel, cardsViewModel: cardsViewModel)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.currentStep != .processing {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if viewModel.currentStep != .goal {
                            Button("Zurück") {
                                viewModel.previousStep()
                            }
                        } else {
                            Button("Abbrechen") {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var navigationTitle: String {
        switch viewModel.currentStep {
        case .goal: return "Ziel definieren"
        case .sources: return "Quellen hinzufügen"
        case .processing: return "Karten werden erstellt"
        case .review: return "Karten durchsehen"
        }
    }
}

struct GoalStepView: View {
    @ObservedObject var viewModel: AICardsViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Was möchtest du lernen?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Beschreibe kurz, welche Informationen du mit den Karteikarten erlernen möchtest. Dies hilft der KI, passende Karten zu erstellen.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            TextEditor(text: $viewModel.goal)
                .frame(minHeight: 150)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                viewModel.nextStep()
            }) {
                Text("Weiter")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.goal.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(viewModel.goal.isEmpty)
            .padding()
        }
    }
}

struct SourcesStepView: View {
    @ObservedObject var viewModel: AICardsViewModel
    @Binding var textInput: String
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var selectedPDF: URL?
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quellen hinzufügen")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Füge PDFs, Text oder Bilder hinzu, aus denen Karteikarten erstellt werden sollen.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            // Text Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Text eingeben:")
                    .font(.headline)
                
                TextEditor(text: $textInput)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                Button(action: {
                    if !textInput.isEmpty {
                        viewModel.addTextSource(textInput)
                        textInput = ""
                    }
                }) {
                    Label("Text hinzufügen", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(textInput.isEmpty)
            }
            .padding(.horizontal)
            
            Divider()
            
            // PDF Upload
            VStack(alignment: .leading, spacing: 8) {
                Text("PDF hochladen:")
                    .font(.headline)
                
                DocumentPicker { url in
                    if let url = url {
                        do {
                            let data = try Data(contentsOf: url)
                            let filename = url.lastPathComponent
                            viewModel.addPDFSource(data, filename: filename)
                        } catch {
                            // Error handling
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            // Selected Sources
            if !viewModel.selectedSources.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hinzugefügte Quellen:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    List {
                        ForEach(viewModel.selectedSources) { source in
                            HStack {
                                Image(systemName: sourceIcon(for: source.type))
                                Text(sourceLabel(for: source))
                                Spacer()
                                Button(action: {
                                    viewModel.removeSource(source)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
            
            Spacer()
            
            Button(action: {
                viewModel.nextStep()
            }) {
                Text("Karten generieren")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.selectedSources.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(viewModel.selectedSources.isEmpty)
            .padding()
        }
    }
    
    private func sourceIcon(for type: SourceType) -> String {
        switch type {
        case .text: return "text.alignleft"
        case .pdf: return "doc.fill"
        case .image: return "photo.fill"
        }
    }
    
    private func sourceLabel(for source: SourceItem) -> String {
        switch source.type {
        case .text:
            let preview = source.content?.prefix(50) ?? ""
            return "Text: \(preview)..."
        case .pdf:
            return "PDF: \(source.filename ?? "Unbekannt")"
        case .image:
            return "Bild: \(source.filename ?? "Unbekannt")"
        }
    }
}

struct ProcessingStepView: View {
    @ObservedObject var viewModel: AICardsViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2)
            
            Text("KI erstellt deine Karteikarten...")
                .font(.headline)
            
            Text("Dies kann einen Moment dauern")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ReviewStepView: View {
    @ObservedObject var viewModel: AICardsViewModel
    @ObservedObject var cardsViewModel: CardsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var dragOffset: CGSize = .zero
    @State private var dragAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Progress Indicator
            HStack {
                Text("\(currentIndex + 1) / \(viewModel.suggestedCards.count)")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.selectedCards.count) ausgewählt")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            // Card Stack
            ZStack {
                ForEach(Array(viewModel.suggestedCards.enumerated()), id: \.element.id) { index, card in
                    if index >= currentIndex && index < currentIndex + 3 {
                        CardPreviewView(
                            card: card,
                            isSelected: viewModel.selectedCards.contains(card.id),
                            offset: index == currentIndex ? dragOffset : .zero,
                            angle: index == currentIndex ? dragAngle : 0,
                            onToggle: {
                                viewModel.toggleCardSelection(card.id)
                            }
                        )
                        .zIndex(Double(viewModel.suggestedCards.count - index))
                        .opacity(index == currentIndex ? 1 : 0.7)
                        .scaleEffect(index == currentIndex ? 1 : 0.9)
                    }
                }
            }
            .frame(height: 400)
            .padding()
            
            // Actions
            HStack(spacing: 20) {
                Button(action: {
                    if currentIndex > 0 {
                        currentIndex -= 1
                    }
                }) {
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .frame(width: 60, height: 60)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(Circle())
                }
                .disabled(currentIndex == 0)
                
                Button(action: {
                    viewModel.toggleCardSelection(viewModel.suggestedCards[currentIndex].id)
                }) {
                    Image(systemName: viewModel.selectedCards.contains(viewModel.suggestedCards[currentIndex].id) ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundColor(viewModel.selectedCards.contains(viewModel.suggestedCards[currentIndex].id) ? .green : .gray)
                }
                
                Button(action: {
                    if currentIndex < viewModel.suggestedCards.count - 1 {
                        currentIndex += 1
                    }
                }) {
                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .frame(width: 60, height: 60)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(Circle())
                }
                .disabled(currentIndex >= viewModel.suggestedCards.count - 1)
            }
            .padding()
            
            // Save Button
            Button(action: {
                Task {
                    await viewModel.saveSelectedCards(cardsViewModel: cardsViewModel)
                    dismiss()
                }
            }) {
                Text("\(viewModel.selectedCards.count) Karten speichern")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.selectedCards.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(viewModel.selectedCards.isEmpty)
            .padding()
        }
    }
}

struct CardPreviewView: View {
    let card: CardSuggestion
    let isSelected: Bool
    var offset: CGSize
    var angle: Double = 0
    let onToggle: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Selection Indicator
            HStack {
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .gray)
                    .font(.title2)
            }
            .padding()
            
            // Front
            VStack(alignment: .leading, spacing: 8) {
                Text("Vorderseite")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(card.front)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Back
            VStack(alignment: .leading, spacing: 8) {
                Text("Rückseite")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(card.back)
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Tags
            if let tags = card.tags, !tags.isEmpty {
                Text(tags)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 5)
                        .offset(offset)
                        .rotationEffect(.degrees(angle))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                    dragAngle = Double(value.translation.width / 20)
                                }
                                .onEnded { value in
                                    let threshold: CGFloat = 100
                                    if abs(value.translation.width) > threshold {
                                        // Swipe left (next) or right (previous)
                                        if value.translation.width > 0 && currentIndex > 0 {
                                            currentIndex -= 1
                                        } else if value.translation.width < 0 && currentIndex < viewModel.suggestedCards.count - 1 {
                                            currentIndex += 1
                                        }
                                    }
                                    dragOffset = .zero
                                    dragAngle = 0
                                }
                        )
    }
}

