import SwiftUI

struct CardsView: View {
    let boxId: String
    @StateObject private var viewModel: CardsViewModel
    @State private var showAddCard = false
    
    init(boxId: String) {
        self.boxId = boxId
        _viewModel = StateObject(wrappedValue: CardsViewModel(boxId: boxId))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                SearchBar(text: $viewModel.searchText)
                    .padding(.horizontal)
                
                // Cards List
                if viewModel.isLoading && viewModel.cards.isEmpty {
                    ProgressView("Lade Karten...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredCards.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "square.stack")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text(viewModel.searchText.isEmpty ? "Noch keine Karten" : "Keine Ergebnisse")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.filteredCards) { card in
                            NavigationLink(destination: CardDetailView(card: card, viewModel: viewModel)) {
                                CardRowView(card: card)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let card = viewModel.filteredCards[index]
                                Task {
                                    await viewModel.deleteCard(card)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Karten")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddCard = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCard) {
                AddCardView(viewModel: viewModel)
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

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Suchen...", text: $text)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct CardRowView: View {
    let card: Card
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.front)
                .font(.headline)
            Text(card.back)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            HStack {
                if !card.tagsArray.isEmpty {
                    ForEach(card.tagsArray.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                Spacer()
                Text(card.due, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CardDetailView: View {
    let card: Card
    @ObservedObject var viewModel: CardsViewModel
    @State private var showEdit = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vorderseite")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(card.front)
                        .font(.title2)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rückseite")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(card.back)
                        .font(.title3)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                
                if !card.tagsArray.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.caption)
                            .foregroundColor(.gray)
                        FlowLayout(items: card.tagsArray) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Statistiken")
                        .font(.headline)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Wiederholungen")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(card.reps)")
                                .font(.title3)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Fehler")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(card.lapses)")
                                .font(.title3)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Fällig")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(card.due, style: .relative)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Karte")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Bearbeiten") {
                    showEdit = true
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditCardView(card: card, viewModel: viewModel)
        }
    }
}

struct FlowLayout: View {
    let items: [String]
    let content: (String) -> AnyView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.chunked(into: 3)), id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                    Spacer()
                }
            }
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

struct AddCardView: View {
    @ObservedObject var viewModel: CardsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var front = ""
    @State private var back = ""
    @State private var tags = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Neue Karte")) {
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
                    Button("Speichern") {
                        Task {
                            await viewModel.createCard(front: front, back: back, tags: tags.isEmpty ? nil : tags)
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
    let card: Card
    @ObservedObject var viewModel: CardsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var front: String
    @State private var back: String
    @State private var tags: String
    
    init(card: Card, viewModel: CardsViewModel) {
        self.card = card
        self.viewModel = viewModel
        _front = State(initialValue: card.front)
        _back = State(initialValue: card.back)
        _tags = State(initialValue: card.tags ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Karte bearbeiten")) {
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
                            await viewModel.updateCard(card, front: front, back: back, tags: tags.isEmpty ? nil : tags)
                            dismiss()
                        }
                    }
                    .disabled(front.isEmpty || back.isEmpty)
                }
            }
        }
    }
}

