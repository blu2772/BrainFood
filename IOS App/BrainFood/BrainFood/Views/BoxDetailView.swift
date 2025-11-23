//
//  BoxDetailView.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import SwiftUI

struct BoxDetailView: View {
    let box: Box
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LearningView(boxId: box.id)
                .tabItem {
                    Label("Lernen", systemImage: "brain")
                }
                .tag(0)
            
            NavigationStack {
                CardsView(boxId: box.id)
            }
            .tabItem {
                Label("Karten", systemImage: "rectangle.stack")
            }
            .tag(1)
            
            BoxSettingsView(box: box)
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
                .tag(2)
        }
        .navigationTitle(box.name)
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        BoxDetailView(box: Box(
            id: "1",
            userId: "1",
            name: "Beispiel Box",
            createdAt: "2024-01-01T00:00:00Z"
        ))
    }
}

