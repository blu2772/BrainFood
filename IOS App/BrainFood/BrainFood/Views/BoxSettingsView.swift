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
    
    var body: some View {
        Form {
            Section("Box") {
                Text("Name: \(box.name)")
                Text("Erstellt: \(formatDate(box.createdAt))")
            }
            
            Section("Konto") {
                Button("Abmelden", role: .destructive) {
                    authViewModel.logout()
                }
            }
        }
        .navigationTitle("Einstellungen")
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

