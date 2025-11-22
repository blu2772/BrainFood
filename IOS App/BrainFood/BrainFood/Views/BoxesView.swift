import SwiftUI

struct BoxesView: View {
    @StateObject private var viewModel = BoxesViewModel()
    @State private var showAddBox = false
    @State private var newBoxName = ""
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.boxes.isEmpty {
                    ProgressView("Lade Boxen...")
                } else if viewModel.boxes.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Noch keine Boxen")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Erstelle deine erste Box, um zu beginnen")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(viewModel.boxes) { box in
                            NavigationLink(destination: BoxDetailView(box: box)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(box.name)
                                        .font(.headline)
                                    if let count = box.cardCount {
                                        Text("\(count) Karten")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                Task {
                                    await viewModel.deleteBox(viewModel.boxes[index])
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Deine Boxen")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddBox = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Neue Box", isPresented: $showAddBox) {
                TextField("Box-Name", text: $newBoxName)
                Button("Erstellen") {
                    Task {
                        await viewModel.createBox(name: newBoxName)
                        newBoxName = ""
                    }
                }
                Button("Abbrechen", role: .cancel) {
                    newBoxName = ""
                }
            } message: {
                Text("Gib einen Namen für deine neue Box ein")
            }
            .task {
                await viewModel.loadBoxes()
            }
            .refreshable {
                await viewModel.loadBoxes()
            }
        }
    }
}

