import SwiftUI

struct BoxSettingsView: View {
    let box: Box
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showLogoutAlert = false
    
    var body: some View {
        List {
            Section(header: Text("Box")) {
                Text("Name: \(box.name)")
                if let count = box.cardCount {
                    Text("Karten: \(count)")
                }
            }
            
            Section(header: Text("Konto")) {
                if let user = authViewModel.currentUser {
                    Text("Benutzer: \(user.name)")
                    Text("E-Mail: \(user.email)")
                }
                
                Button("Abmelden", role: .destructive) {
                    showLogoutAlert = true
                }
            }
        }
        .navigationTitle("Einstellungen")
        .alert("Abmelden", isPresented: $showLogoutAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Abmelden", role: .destructive) {
                authViewModel.logout()
            }
        } message: {
            Text("Möchten Sie sich wirklich abmelden?")
        }
    }
}

