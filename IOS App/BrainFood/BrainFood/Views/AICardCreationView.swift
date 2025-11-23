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
    @State private var selectedPhotos: [PhotosPickerItem] = []
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
                        selectedPhotos: $selectedPhotos,
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
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var selectedPDF: URL?
    @State private var showingImagePicker = false
    @State private var showingPDFPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("Quellen hinzufügen")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Wähle PDFs oder Bilder aus, aus denen Karteikarten erstellt werden sollen.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            // Main Content - Buttons
            ScrollView {
                VStack(spacing: 20) {
                    // PDF Button
                    Button(action: {
                        showingPDFPicker = true
                    }) {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            Text("PDF auswählen")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Text("Wähle PDF-Dateien aus")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(radius: 10)
                    }
                    .padding(.horizontal)
                    
                    // Image Button
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            Text("Bilder auswählen")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Text("Wähle Bilder aus der Galerie")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(radius: 10)
                    }
                    .padding(.horizontal)
                    
                    // Selected Sources List
                    if !viewModel.selectedSources.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ausgewählte Quellen (\(viewModel.selectedSources.count))")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                ForEach(viewModel.selectedSources) { source in
                                    HStack {
                                        Image(systemName: sourceIcon(for: source.type))
                                            .font(.title2)
                                            .foregroundColor(sourceColor(for: source.type))
                                            .frame(width: 40)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(sourceLabel(for: source))
                                                .font(.body)
                                                .fontWeight(.medium)
                                            if let filename = source.filename {
                                                Text(filename)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            viewModel.removeSource(source)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .font(.title3)
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                    }
                }
                .padding(.vertical)
            }
            
            // Generate Button - Immer sichtbar am unteren Rand
            VStack(spacing: 8) {
                if viewModel.selectedSources.isEmpty {
                    Text("Bitte füge mindestens eine Quelle hinzu")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    viewModel.nextStep()
                }) {
                    HStack {
                        Text("Karten generieren")
                            .font(.headline)
                        if !viewModel.selectedSources.isEmpty {
                            Text("(\(viewModel.selectedSources.count))")
                                .font(.subheadline)
                                .opacity(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.selectedSources.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.selectedSources.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showingPDFPicker) {
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
                showingPDFPicker = false
            }
        }
        .photosPicker(
            isPresented: $showingImagePicker,
            selection: $selectedPhotos,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: selectedPhotos) { oldValue, newValue in
            // Verarbeite neue Fotos
            let existingCount = viewModel.selectedSources.filter { $0.type == .image }.count
            let newPhotos = newValue.suffix(newValue.count - oldValue.count)
            
            for (index, photo) in newPhotos.enumerated() {
                Task {
                    if let data = try? await photo.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            let filename = "image_\(existingCount + index + 1).jpg"
                            viewModel.addImageSource(data, filename: filename)
                        }
                    }
                }
            }
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
            return source.filename ?? "PDF-Dokument"
        case .image:
            return source.filename ?? "Bild"
        }
    }
    
    private func sourceColor(for type: SourceType) -> Color {
        switch type {
        case .text:
            return .blue
        case .pdf:
            return .blue
        case .image:
            return .purple
        }
    }
}

struct ProcessingStepView: View {
    @ObservedObject var viewModel: AICardsViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Animated Brain Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            // Status Text
            VStack(spacing: 12) {
                Text(viewModel.currentStatus.isEmpty ? "KI erstellt deine Karteikarten..." : viewModel.currentStatus)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentStatus)
                    .transition(.opacity.combined(with: .scale))
                    .id(viewModel.currentStatus) // Force re-render on change
                
                if viewModel.currentStatus.isEmpty {
                    Text("Dies kann einen Moment dauern")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(minHeight: 80)
            
            // Progress Bar
            VStack(spacing: 8) {
                ProgressView(value: viewModel.processingProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                Text("\(Int(viewModel.processingProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 40)
            
            // Thinking Animation
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .scaleEffect(viewModel.isProcessing ? 1.0 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: viewModel.isProcessing
                        )
                }
            }
            .padding(.top)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .padding(.top)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
                            },
                            onDragChanged: { translation in
                                dragOffset = translation
                                dragAngle = Double(translation.width / 20)
                            },
                            onDragEnded: { translation in
                                let threshold: CGFloat = 100
                                if abs(translation.width) > threshold {
                                    // Swipe left (next) or right (previous)
                                    if translation.width > 0 && currentIndex > 0 {
                                        currentIndex -= 1
                                    } else if translation.width < 0 && currentIndex < viewModel.suggestedCards.count - 1 {
                                        currentIndex += 1
                                    }
                                }
                                dragOffset = .zero
                                dragAngle = 0
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
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void
    
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
                                    onDragChanged(value.translation)
                                }
                                .onEnded { value in
                                    onDragEnded(value.translation)
                                }
                        )
    }
}

