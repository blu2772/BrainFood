//
//  CardSuggestion.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import Foundation

struct CardSuggestion: Codable, Identifiable {
    let id: String
    let front: String
    let back: String
    let tags: String?
    
    init(front: String, back: String, tags: String? = nil) {
        self.id = UUID().uuidString
        self.front = front
        self.back = back
        self.tags = tags
    }
    
    // Custom CodingKeys für Backend-Response (ohne id)
    enum CodingKeys: String, CodingKey {
        case front, back, tags
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString // Generiere ID beim Decode
        self.front = try container.decode(String.self, forKey: .front)
        self.back = try container.decode(String.self, forKey: .back)
        self.tags = try container.decodeIfPresent(String.self, forKey: .tags)
    }
}

struct CardSuggestionsResponse: Codable {
    let message: String
    let cards: [CardSuggestion]
}

