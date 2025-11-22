//
//  BoxesViewModel.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class BoxesViewModel: ObservableObject {
    @Published var boxes: [Box] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    func loadBoxes() async {
        isLoading = true
        errorMessage = nil
        
        do {
            boxes = try await apiClient.getBoxes()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Fehler beim Laden der Boxen"
        }
        
        isLoading = false
    }
    
    func createBox(name: String) async {
        do {
            let newBox = try await apiClient.createBox(name: name)
            boxes.append(newBox)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Fehler beim Erstellen der Box"
        }
    }
    
    func deleteBox(_ box: Box) async {
        do {
            try await apiClient.deleteBox(boxId: box.id)
            boxes.removeAll { $0.id == box.id }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Fehler beim Löschen der Box"
        }
    }
}

