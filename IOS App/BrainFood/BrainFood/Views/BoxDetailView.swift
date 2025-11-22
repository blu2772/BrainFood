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
            
            CardsView(boxId: box.id)
                .tabItem {
                    Label("Karten", systemImage: "square.stack")
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

