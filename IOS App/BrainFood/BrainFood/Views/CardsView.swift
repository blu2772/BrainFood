//
//  CardsView.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import SwiftUI

struct CardsView: View {
    let boxId: String
    @StateObject private var viewModel: CardsViewModel
    @State private var showingAddCard = false
    @State private var selectedCard: Card?
    
    init(boxId: String) {
        self.boxId = boxId
        _viewModel = StateObject(wrappedValue: CardsViewModel(boxId: boxId))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search Bar
                SearchBar(text: $viewModel.searchText)
                    .padding(.horizontal)
                
                // Cards List
                if viewModel.isLoading && viewModel.filteredCards.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredCards.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Noch keine Karten")
                            .font(.headline)
                        Text("Erstelle deine erste Karteikarte")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.filteredCards) { card in
                            CardRow(card: card)
                                .onTapGesture {
                                    selectedCard = card
                                }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                Task {
                                    await viewModel.deleteCard(viewModel.filteredCards[index])
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Karten")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddCard = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCard) {
                AddCardView(viewModel: viewModel)
            }
            .sheet(item: $selectedCard) { card in
                EditCardView(viewModel: viewModel, card: card)
            }
            .task {
                await viewModel.loadCards()
            }
            .refreshable {
                await viewModel.loadCards()
            }
        }
    }
}

struct CardRow: View {
    let card: Card
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.front)
                .font(.headline)
            Text(card.back)
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack {
                if let tags = card.tags, !tags.isEmpty {
                    Text(tags)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Spacer()
                Text("Fällig: \(formatDate(card.due))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Suchen...", text: $text)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct AddCardView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CardsViewModel
    @State private var front = ""
    @State private var back = ""
    @State private var tags = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Karte") {
                    TextField("Vorderseite", text: $front)
                    TextField("Rückseite", text: $back)
                    TextField("Tags (kommagetrennt)", text: $tags)
                }
            }
            .navigationTitle("Neue Karte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Erstellen") {
                        Task {
                            await viewModel.createCard(
                                front: front,
                                back: back,
                                tags: tags.isEmpty ? nil : tags
                            )
                            dismiss()
                        }
                    }
                    .disabled(front.isEmpty || back.isEmpty)
                }
            }
        }
    }
}

struct EditCardView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CardsViewModel
    let card: Card
    @State private var front: String
    @State private var back: String
    @State private var tags: String
    
    init(viewModel: CardsViewModel, card: Card) {
        self.viewModel = viewModel
        self.card = card
        _front = State(initialValue: card.front)
        _back = State(initialValue: card.back)
        _tags = State(initialValue: card.tags ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Karte") {
                    TextField("Vorderseite", text: $front)
                    TextField("Rückseite", text: $back)
                    TextField("Tags (kommagetrennt)", text: $tags)
                }
            }
            .navigationTitle("Karte bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        Task {
                            await viewModel.updateCard(
                                cardId: card.id,
                                front: front,
                                back: back,
                                tags: tags.isEmpty ? nil : tags
                            )
                            dismiss()
                        }
                    }
                    .disabled(front.isEmpty || back.isEmpty)
                }
            }
        }
    }
}

#Preview {
    CardsView(boxId: "1")
}

