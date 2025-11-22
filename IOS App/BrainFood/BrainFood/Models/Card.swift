//
//  Card.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import Foundation

struct Card: Codable, Identifiable {
    let id: String
    let boxId: String
    let front: String
    let back: String
    let tags: String?
    let stability: Double
    let difficulty: Double
    let reps: Int
    let lapses: Int
    let lastReviewAt: String?
    let due: String
    let createdAt: String
    let updatedAt: String
}

struct CardsResponse: Codable {
    let cards: [Card]
}

struct ReviewRating: Codable {
    let rating: String // "again", "hard", "good", "easy"
}

struct ReviewResponse: Codable {
    let card: Card
    let nextDue: String
    let interval: Int
}

struct NextReviewsResponse: Codable {
    let cards: [Card]
    let count: Int
}

