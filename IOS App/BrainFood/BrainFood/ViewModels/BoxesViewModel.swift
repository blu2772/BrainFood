import Foundation
import SwiftUI

class BoxesViewModel: ObservableObject {
    @Published var boxes: [Box] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    @MainActor
    func loadBoxes() async {
        isLoading = true
        errorMessage = nil
        
        do {
            boxes = try await apiClient.getBoxes()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func createBox(name: String) async {
        do {
            let newBox = try await apiClient.createBox(name: name)
            boxes.append(newBox)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func deleteBox(_ box: Box) async {
        do {
            try await apiClient.deleteBox(boxId: box.id)
            boxes.removeAll { $0.id == box.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

