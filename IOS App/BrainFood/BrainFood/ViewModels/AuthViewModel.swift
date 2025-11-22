//
//  AuthViewModel.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    private let keychain = KeychainService.shared
    
    init() {
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        if keychain.getToken() != nil {
            Task {
                await loadCurrentUser()
            }
        }
    }
    
    func loadCurrentUser() async {
        do {
            let user = try await apiClient.getCurrentUser()
            self.currentUser = user
            self.isAuthenticated = true
        } catch {
            // Token ungültig, ausloggen
            logout()
        }
    }
    
    func register(name: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiClient.register(name: name, email: email, password: password)
            keychain.saveToken(response.token)
            self.currentUser = response.user
            self.isAuthenticated = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Ein Fehler ist aufgetreten"
        }
        
        isLoading = false
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiClient.login(email: email, password: password)
            keychain.saveToken(response.token)
            self.currentUser = response.user
            self.isAuthenticated = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Ein Fehler ist aufgetreten"
        }
        
        isLoading = false
    }
    
    func logout() {
        keychain.deleteToken()
        currentUser = nil
        isAuthenticated = false
    }
}

