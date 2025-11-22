import Foundation

struct Card: Codable, Identifiable {
    let id: String
    let boxId: String
    let front: String
    let back: String
    let tags: String?
    let createdAt: Date
    let updatedAt: Date
    let stability: Double
    let difficulty: Double
    let reps: Int
    let lapses: Int
    let lastReviewAt: Date?
    let due: Date
    
    var tagsArray: [String] {
        tags?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }
}

struct CardsResponse: Codable {
    let cards: [Card]
}

enum ReviewRating: String, Codable, CaseIterable {
    case again = "again"
    case hard = "hard"
    case good = "good"
    case easy = "easy"
    
    var displayName: String {
        switch self {
        case .again: return "Wiederholen"
        case .hard: return "Schwer"
        case .good: return "Gut"
        case .easy: return "Einfach"
        }
    }
    
    var color: String {
        switch self {
        case .again: return "red"
        case .hard: return "orange"
        case .good: return "green"
        case .easy: return "blue"
        }
    }
}

struct ReviewRequest: Codable {
    let rating: String
}

struct ReviewResponse: Codable {
    let card: Card
    let nextDue: Date
    let interval: Int
}
