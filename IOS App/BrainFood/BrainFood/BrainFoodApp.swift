//
//  BrainFoodApp.swift
//  BrainFood
//
//  Created by Tim Rempel on 22.11.25.
//

import SwiftUI

@main
struct BrainFoodApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            if authViewModel.isAuthenticated {
                BoxesView()
                    .environmentObject(authViewModel)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
