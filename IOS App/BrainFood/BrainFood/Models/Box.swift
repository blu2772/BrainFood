import Foundation

struct Box: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let createdAt: Date
    let cardCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case name
        case createdAt
        case cardCount = "_count"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        if let count = try? container.decode(Count.self, forKey: .cardCount) {
            cardCount = count.cards
        } else {
            cardCount = nil
        }
    }
    
    struct Count: Codable {
        let cards: Int
    }
}

struct BoxesResponse: Codable {
    let boxes: [Box]
}
