import Foundation
import SwiftUI

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
        if let user = keychain.getUser(), let _ = keychain.getToken() {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func register(name: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiClient.register(name: name, email: email, password: password)
            keychain.saveToken(response.token)
            keychain.saveUser(response.user)
            currentUser = response.user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiClient.login(email: email, password: password)
            keychain.saveToken(response.token)
            keychain.saveUser(response.user)
            currentUser = response.user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func logout() {
        keychain.clearAll()
        currentUser = nil
        isAuthenticated = false
    }
}

