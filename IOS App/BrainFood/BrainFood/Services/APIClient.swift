import Foundation

class APIClient {
    static let shared = APIClient()
    
    private let baseURL: String
    private let session: URLSession
    
    private init() {
        // TODO: Update this to your backend URL
        self.baseURL = "http://localhost:3000/api"
        self.session = URLSession.shared
    }
    
    // MARK: - Authentication
    
    func register(name: String, email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["name": name, "email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder.brainFoodDecoder.decode(AuthResponse.self, from: data)
    }
    
    func login(email: String, password: String) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder.brainFoodDecoder.decode(AuthResponse.self, from: data)
    }
    
    func getCurrentUser() async throws -> User {
        let url = URL(string: "\(baseURL)/auth/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        let responseObj = try JSONDecoder.brainFoodDecoder.decode([String: User].self, from: data)
        return responseObj["user"]!
    }
    
    // MARK: - Boxes
    
    func getBoxes() async throws -> [Box] {
        let url = URL(string: "\(baseURL)/boxes")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        let responseObj = try JSONDecoder.brainFoodDecoder.decode(BoxesResponse.self, from: data)
        return responseObj.boxes
    }
    
    func createBox(name: String) async throws -> Box {
        let url = URL(string: "\(baseURL)/boxes")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try addAuthHeader(to: &request)
        
        let body = ["name": name]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        let responseObj = try JSONDecoder.brainFoodDecoder.decode([String: Box].self, from: data)
        return responseObj["box"]!
    }
    
    func updateBox(boxId: String, name: String) async throws -> Box {
        let url = URL(string: "\(baseURL)/boxes/\(boxId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try addAuthHeader(to: &request)
        
        let body = ["name": name]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        let responseObj = try JSONDecoder.brainFoodDecoder.decode([String: Box].self, from: data)
        return responseObj["box"]!
    }
    
    func deleteBox(boxId: String) async throws {
        let url = URL(string: "\(baseURL)/boxes/\(boxId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        try addAuthHeader(to: &request)
        
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }
    
    // MARK: - Cards
    
    func getCards(boxId: String, search: String? = nil, sort: String? = nil) async throws -> [Card] {
        var components = URLComponents(string: "\(baseURL)/boxes/\(boxId)/cards")!
        var queryItems: [URLQueryItem] = []
        if let search = search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if let sort = sort {
            queryItems.append(URLQueryItem(name: "sort", value: sort))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        try addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        let responseObj = try JSONDecoder.brainFoodDecoder.decode(CardsResponse.self, from: data)
        return responseObj.cards
    }
    
    func createCard(boxId: String, front: String, back: String, tags: String?) async throws -> Card {
        let url = URL(string: "\(baseURL)/boxes/\(boxId)/cards")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try addAuthHeader(to: &request)
        
        var body: [String: Any] = ["front": front, "back": back]
        if let tags = tags {
            body["tags"] = tags
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        let responseObj = try JSONDecoder.brainFoodDecoder.decode([String: Card].self, from: data)
        return responseObj["card"]!
    }
    
    func updateCard(cardId: String, front: String?, back: String?, tags: String?) async throws -> Card {
        let url = URL(string: "\(baseURL)/cards/\(cardId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try addAuthHeader(to: &request)
        
        var body: [String: Any] = [:]
        if let front = front { body["front"] = front }
        if let back = back { body["back"] = back }
        if let tags = tags { body["tags"] = tags }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        let responseObj = try JSONDecoder.brainFoodDecoder.decode([String: Card].self, from: data)
        return responseObj["card"]!
    }
    
    func deleteCard(cardId: String) async throws {
        let url = URL(string: "\(baseURL)/cards/\(cardId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        try addAuthHeader(to: &request)
        
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }
    
    // MARK: - Reviews
    
    func getNextReviews(boxId: String, limit: Int = 1) async throws -> [Card] {
        let url = URL(string: "\(baseURL)/boxes/\(boxId)/reviews/next?limit=\(limit)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        let responseObj = try JSONDecoder.brainFoodDecoder.decode(CardsResponse.self, from: data)
        return responseObj.cards
    }
    
    func submitReview(cardId: String, rating: ReviewRating) async throws -> ReviewResponse {
        let url = URL(string: "\(baseURL)/cards/\(cardId)/review")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try addAuthHeader(to: &request)
        
        let body = ["rating": rating.rawValue]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder.brainFoodDecoder.decode(ReviewResponse.self, from: data)
    }
    
    // MARK: - Stats
    
    func getBoxStats(boxId: String) async throws -> BoxStats {
        let url = URL(string: "\(baseURL)/boxes/\(boxId)/stats")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try addAuthHeader(to: &request)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONDecoder.brainFoodDecoder.decode(BoxStats.self, from: data)
    }
    
    // MARK: - Helpers
    
    private func addAuthHeader(to request: inout URLRequest) throws {
        guard let token = KeychainService.shared.getToken() else {
            throw APIError.unauthorized
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 400...499:
            throw APIError.clientError(httpResponse.statusCode)
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.unknown
        }
    }
}

enum APIError: Error, LocalizedError {
    case unauthorized
    case notFound
    case clientError(Int)
    case serverError(Int)
    case invalidResponse
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Nicht autorisiert. Bitte melden Sie sich erneut an."
        case .notFound:
            return "Ressource nicht gefunden."
        case .clientError(let code):
            return "Client-Fehler (\(code))"
        case .serverError(let code):
            return "Server-Fehler (\(code))"
        case .invalidResponse:
            return "Ungültige Server-Antwort."
        case .unknown:
            return "Ein unbekannter Fehler ist aufgetreten."
        }
    }
}

// MARK: - Date Decoding

extension JSONDecoder {
    static let brainFoodDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Fallback to standard ISO8601
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(dateString)"
            )
        }
        return decoder
    }()
}

