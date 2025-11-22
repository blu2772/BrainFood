//
//  BoxesView.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import SwiftUI

struct BoxesView: View {
    @StateObject private var viewModel = BoxesViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showingAddBox = false
    @State private var newBoxName = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.boxes.isEmpty {
                    ProgressView()
                } else if viewModel.boxes.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Noch keine Boxen")
                            .font(.headline)
                        Text("Erstelle deine erste Box für deine Karteikarten")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.boxes) { box in
                            NavigationLink(destination: BoxDetailView(box: box)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(box.name)
                                        .font(.headline)
                                    Text("Erstellt: \(formatDate(box.createdAt))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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
                    Button(action: {
                        showingAddBox = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abmelden") {
                        authViewModel.logout()
                    }
                }
            }
            .sheet(isPresented: $showingAddBox) {
                AddBoxView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadBoxes()
            }
            .refreshable {
                await viewModel.loadBoxes()
            }
        }
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

struct AddBoxView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BoxesViewModel
    @State private var name = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Box-Name", text: $name)
            }
            .navigationTitle("Neue Box")
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
                            await viewModel.createBox(name: name)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    BoxesView()
}

