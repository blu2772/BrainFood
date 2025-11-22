//
//  ApiKeysViewModel.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ApiKeysViewModel: ObservableObject {
    @Published var keys: [ApiKey] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var newKey: ApiKeyResponse?
    @Published var showingNewKey = false
    
    // Computed property für den Key-String
    var newKeyString: String {
        newKey?.key ?? ""
    }
    
    private let apiClient = APIClient.shared
    
    func loadKeys() async {
        isLoading = true
        errorMessage = nil
        
        do {
            keys = try await apiClient.getApiKeys()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Fehler beim Laden der API-Keys"
        }
        
        isLoading = false
    }
    
    func createKey() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiClient.createApiKey()
            newKey = response
            showingNewKey = true
            // Lade Keys neu
            await loadKeys()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Fehler beim Erstellen des API-Keys"
        }
        
        isLoading = false
    }
    
    func deleteKey(_ key: ApiKey) async {
        do {
            try await apiClient.deleteApiKey(keyId: key.id)
            await loadKeys()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Fehler beim Löschen des API-Keys"
        }
    }
}

