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
    @State private var showingNewKeySheet = false
    
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
            .sheet(isPresented: $viewModel.showingNewKey) {
                if let apiKey = viewModel.newKey?.key {
                    NewApiKeySheet(apiKey: apiKey, onDismiss: {
                        viewModel.showingNewKey = false
                    })
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

struct NewApiKeySheet: View {
    let apiKey: String
    let onDismiss: () -> Void
    @State private var copied = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dein API-Key")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Dieser Key ist 60 Minuten gültig und wird nicht erneut angezeigt. Speichere ihn jetzt!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("⚠️ Wichtig: Kopiere diesen Key sofort!")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("API-Key:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("", text: .constant(apiKey))
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                        .disabled(true)
                }
                .padding(.horizontal)
                
                Button(action: {
                    UIPasteboard.general.string = apiKey
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                }) {
                    HStack {
                        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                        Text(copied ? "Kopiert!" : "In Zwischenablage kopieren")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Neuer API-Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        onDismiss()
                    }
                }
            }
        }
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

