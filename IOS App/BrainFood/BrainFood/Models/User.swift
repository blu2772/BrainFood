import Foundation

struct User: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case createdAt
    }
}

struct AuthResponse: Codable {
    let user: User
    let token: String
}
