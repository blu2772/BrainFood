import Foundation
import SwiftUI

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
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func createBox(name: String) async {
        do {
            let newBox = try await apiClient.createBox(name: name)
            boxes.append(newBox)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteBox(_ box: Box) async {
        do {
            try await apiClient.deleteBox(boxId: box.id)
            boxes.removeAll { $0.id == box.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

