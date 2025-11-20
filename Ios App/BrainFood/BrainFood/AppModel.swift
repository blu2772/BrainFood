import Foundation

struct Card: Identifiable, Codable, Equatable {
    let id: String
    var front: String
    var back: String
    var tags: [String]
    var stability: Double
    var difficulty: Double
    var due: Date
    var lastReview: Date?
    var lapses: Int
    var reps: Int
    var history: [ReviewEvent]?
    var createdAt: Date?
    var updatedAt: Date?
}

struct ReviewEvent: Codable, Equatable {
    let rating: Int
    let reviewedAt: Date
    let intervalDays: Int?
}

enum ReviewRating: Int, CaseIterable, Identifiable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }

    var colorName: String {
        switch self {
        case .again: return "red"
        case .hard: return "orange"
        case .good: return "green"
        case .easy: return "blue"
        }
    }
}

struct CreateCardPayload: Codable {
    let front: String
    let back: String
    let tags: [String]
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case server(String)
    case decoding
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Die Server-URL konnte nicht verarbeitet werden."
        case .server(let message): return message
        case .decoding: return "Antwort konnte nicht gelesen werden."
        case .unknown: return "Unerwarteter Fehler."
        }
    }
}

final class APIService {
    static let shared = APIService()
    var baseURL: URL

    init(baseURL: URL = URL(string: "https://BrainFood.timrmp.de")!) {
        self.baseURL = baseURL
    }

    func fetchCards(dueOnly: Bool) async throws -> [Card] {
        var components = URLComponents(url: baseURL.appendingPathComponent("cards"), resolvingAgainstBaseURL: false)
        components?.queryItems = dueOnly ? [URLQueryItem(name: "dueOnly", value: "true")] : nil
        guard let url = components?.url else { throw APIError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder.api.decode([Card].self, from: data)
        return decoded
    }

    func createCard(request: CreateCardPayload) async throws -> Card {
        let url = baseURL.appendingPathComponent("cards")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(request)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response: response, data: data)
        return try JSONDecoder.api.decode(Card.self, from: data)
    }

    func review(cardId: String, rating: ReviewRating) async throws -> Card {
        let url = baseURL.appendingPathComponent("review")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["cardId": cardId, "rating": rating.rawValue] as [String : Any]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response: response, data: data)
        return try JSONDecoder.api.decode(Card.self, from: data)
    }

    private func validate(response: URLResponse?, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard 200..<300 ~= http.statusCode else {
            let serverMessage = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let message = serverMessage?["error"] as? String ?? "Status \(http.statusCode)"
            throw APIError.server(message)
        }
    }
}

extension JSONDecoder {
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var api: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

// Lightweight FSRS fallback (used to show preview instantly while awaiting backend)
struct FSRSCalculator {
    private let requestRetention = 0.9
    private let maxInterval = 365.0

    func next(for card: Card, rating: ReviewRating, now: Date = .init()) -> Card {
        let weights = (
            initStability: 0.4,
            initDifficulty: 5.8,
            stabilityGrowth: 3.0,
            stabilityDecay: 0.6,
            difficultyDecay: 0.25,
            difficultyStep: 0.6,
            easyBonus: 1.3,
            hardPenalty: 0.5,
            lapseReset: 0.2
        )

        let last = card.lastReview ?? now
        let elapsedDays = max(0.04, now.timeIntervalSince(last) / 86_400)
        let retrievability = pow(requestRetention, elapsedDays / max(card.stability, 0.01))
        var difficulty = clamp(card.difficulty + weights.difficultyStep * Double(3 - rating.rawValue), lower: 1, upper: 10)
        var stability: Double
        var lapses = card.lapses

        if rating == .again {
            stability = weights.lapseReset
            difficulty = clamp(difficulty + weights.difficultyDecay, lower: 1, upper: 10)
            lapses += 1
        } else {
            let performance = pow(retrievability, weights.stabilityDecay)
            let adj = rating == .easy ? weights.easyBonus : rating == .hard ? (1 - weights.hardPenalty) : 1
            stability = max(weights.initStability, card.stability * (1 + weights.stabilityGrowth * (1 - performance) * adj))
        }

        let interval = clamp(stability * log(1 / (1 - requestRetention)), lower: 1, upper: maxInterval)
        let nextDue = Calendar.current.date(byAdding: .day, value: Int(interval.rounded()), to: now) ?? now

        return Card(
            id: card.id,
            front: card.front,
            back: card.back,
            tags: card.tags,
            stability: stability,
            difficulty: difficulty,
            due: nextDue,
            lastReview: now,
            lapses: lapses,
            reps: card.reps + 1,
            history: card.history,
            createdAt: card.createdAt,
            updatedAt: now
        )
    }

    private func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
