//
//  BoxSettingsView.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import SwiftUI

struct BoxSettingsView: View {
    let box: Box
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showingApiKeys = false
    
    var body: some View {
        Form {
            Section("Box") {
                Text("Name: \(box.name)")
                Text("Erstellt: \(formatDate(box.createdAt))")
            }
            
            Section("API-Keys für Custom GPT") {
                Button("API-Keys verwalten") {
                    showingApiKeys = true
                }
            }
            
            Section("Konto") {
                Button("Abmelden", role: .destructive) {
                    authViewModel.logout()
                }
            }
        }
        .navigationTitle("Einstellungen")
        .sheet(isPresented: $showingApiKeys) {
            ApiKeysView()
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct ApiKeysView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ApiKeysViewModel()
    @State private var showingNewKeyAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(action: {
                        Task {
                            await viewModel.createKey()
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Neuen API-Key erstellen (60 Min)", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
                
                Section("Deine API-Keys") {
                    if viewModel.keys.isEmpty {
                        Text("Noch keine API-Keys")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.keys) { key in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(key.keyPrefix)...")
                                    .font(.system(.headline, design: .monospaced))
                                Text("Läuft ab: \(formatDate(key.expiresAt))")
                                    .font(.caption)
                                    .foregroundColor(isExpired(key.expiresAt) ? .red : .secondary)
                                if let lastUsed = key.lastUsedAt {
                                    Text("Zuletzt verwendet: \(formatDate(lastUsed))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteKey(key)
                                    }
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("API-Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .alert("Neuer API-Key", isPresented: $viewModel.showingNewKey) {
                Button("OK") {
                    viewModel.showingNewKey = false
                }
            } message: {
                if let newKey = viewModel.newKey {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dein API-Key (60 Minuten gültig):")
                            .font(.headline)
                        Text(newKey.key)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Text("⚠️ Wichtig: Speichere diesen Key jetzt! Er wird nicht erneut angezeigt.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .task {
                await viewModel.loadKeys()
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private func isExpired(_ dateString: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            return date < Date()
        }
        return false
    }
}

#Preview {
    NavigationStack {
        BoxSettingsView(box: Box(
            id: "1",
            userId: "1",
            name: "Beispiel Box",
            createdAt: "2024-01-01T00:00:00Z"
        ))
    }
}

