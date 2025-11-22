//
//  APIClient.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import Foundation

class APIClient {
    static let shared = APIClient()
    
    // TODO: Anpassen an deine Backend-URL
    private let baseURL = "http://localhost:3000/api"
    
    private init() {}
    
    // MARK: - Helper Methods
    
    private func getAuthToken() -> String? {
        return KeychainService.shared.getToken()
    }
    
    private func createRequest(
        endpoint: String,
        method: String,
        body: Data? = nil,
        requiresAuth: Bool = true
    ) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth, let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorData = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorData.error)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Auth Endpoints
    
    func register(name: String, email: String, password: String) async throws -> AuthResponse {
        let body = ["name": name, "email": email, "password": password]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        guard let request = createRequest(
            endpoint: "/auth/register",
            method: "POST",
            body: bodyData,
            requiresAuth: false
        ) else {
            throw APIError.invalidRequest
        }
        
        return try await performRequest(request, responseType: AuthResponse.self)
    }
    
    func login(email: String, password: String) async throws -> AuthResponse {
        let body = ["email": email, "password": password]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        guard let request = createRequest(
            endpoint: "/auth/login",
            method: "POST",
            body: bodyData,
            requiresAuth: false
        ) else {
            throw APIError.invalidRequest
        }
        
        return try await performRequest(request, responseType: AuthResponse.self)
    }
    
    func getCurrentUser() async throws -> User {
        guard let request = createRequest(
            endpoint: "/auth/me",
            method: "GET"
        ) else {
            throw APIError.invalidRequest
        }
        
        let response = try await performRequest(request, responseType: UserResponse.self)
        return response.user
    }
    
    // MARK: - Box Endpoints
    
    func getBoxes() async throws -> [Box] {
        guard let request = createRequest(
            endpoint: "/boxes",
            method: "GET"
        ) else {
            throw APIError.invalidRequest
        }
        
        let response = try await performRequest(request, responseType: BoxesResponse.self)
        return response.boxes
    }
    
    func createBox(name: String) async throws -> Box {
        let body = ["name": name]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        guard let request = createRequest(
            endpoint: "/boxes",
            method: "POST",
            body: bodyData
        ) else {
            throw APIError.invalidRequest
        }
        
        let response = try await performRequest(request, responseType: BoxResponse.self)
        return response.box
    }
    
    func updateBox(boxId: String, name: String) async throws -> Box {
        let body = ["name": name]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        guard let request = createRequest(
            endpoint: "/boxes/\(boxId)",
            method: "PUT",
            body: bodyData
        ) else {
            throw APIError.invalidRequest
        }
        
        let response = try await performRequest(request, responseType: BoxResponse.self)
        return response.box
    }
    
    func deleteBox(boxId: String) async throws {
        guard let request = createRequest(
            endpoint: "/boxes/\(boxId)",
            method: "DELETE"
        ) else {
            throw APIError.invalidRequest
        }
        
        _ = try await URLSession.shared.data(for: request)
    }
    
    // MARK: - Card Endpoints
    
    func getCards(boxId: String, search: String? = nil, sort: String? = nil) async throws -> [Card] {
        var endpoint = "/boxes/\(boxId)/cards"
        var queryItems: [URLQueryItem] = []
        
        if let search = search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if let sort = sort {
            queryItems.append(URLQueryItem(name: "sort", value: sort))
        }
        
        if !queryItems.isEmpty {
            var components = URLComponents(string: "\(baseURL)\(endpoint)")
            components?.queryItems = queryItems
            endpoint = components?.url?.path ?? endpoint
        }
        
        guard let request = createRequest(
            endpoint: endpoint,
            method: "GET"
        ) else {
            throw APIError.invalidRequest
        }
        
        let response = try await performRequest(request, responseType: CardsResponse.self)
        return response.cards
    }
    
    func createCard(boxId: String, front: String, back: String, tags: String?) async throws -> Card {
        var body: [String: Any] = ["front": front, "back": back]
        if let tags = tags {
            body["tags"] = tags
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        guard let request = createRequest(
            endpoint: "/boxes/\(boxId)/cards",
            method: "POST",
            body: bodyData
        ) else {
            throw APIError.invalidRequest
        }
        
        let response = try await performRequest(request, responseType: CardResponse.self)
        return response.card
    }
    
    func updateCard(cardId: String, front: String?, back: String?, tags: String?) async throws -> Card {
        var body: [String: Any] = [:]
        if let front = front { body["front"] = front }
        if let back = back { body["back"] = back }
        if let tags = tags { body["tags"] = tags }
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        guard let request = createRequest(
            endpoint: "/cards/\(cardId)",
            method: "PUT",
            body: bodyData
        ) else {
            throw APIError.invalidRequest
        }
        
        let response = try await performRequest(request, responseType: CardResponse.self)
        return response.card
    }
    
    func deleteCard(cardId: String) async throws {
        guard let request = createRequest(
            endpoint: "/cards/\(cardId)",
            method: "DELETE"
        ) else {
            throw APIError.invalidRequest
        }
        
        _ = try await URLSession.shared.data(for: request)
    }
    
    // MARK: - Review Endpoints
    
    func getNextReviews(boxId: String, limit: Int = 1) async throws -> [Card] {
        guard let request = createRequest(
            endpoint: "/boxes/\(boxId)/reviews/next?limit=\(limit)",
            method: "GET"
        ) else {
            throw APIError.invalidRequest
        }
        
        let response = try await performRequest(request, responseType: NextReviewsResponse.self)
        return response.cards
    }
    
    func reviewCard(cardId: String, rating: String) async throws -> ReviewResponse {
        let body = ["rating": rating]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        guard let request = createRequest(
            endpoint: "/cards/\(cardId)/review",
            method: "POST",
            body: bodyData
        ) else {
            throw APIError.invalidRequest
        }
        
        return try await performRequest(request, responseType: ReviewResponse.self)
    }
    
    // MARK: - Stats Endpoints
    
    func getStats(boxId: String) async throws -> BoxStats {
        guard let request = createRequest(
            endpoint: "/boxes/\(boxId)/stats",
            method: "GET"
        ) else {
            throw APIError.invalidRequest
        }
        
        let response = try await performRequest(request, responseType: StatsResponse.self)
        return response.stats
    }
}

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case invalidRequest
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Ungültige Anfrage"
        case .invalidResponse:
            return "Ungültige Antwort vom Server"
        case .httpError(let code):
            return "HTTP Fehler: \(code)"
        case .serverError(let message):
            return message
        }
    }
}

// MARK: - Response Types

struct ErrorResponse: Codable {
    let error: String
}

struct UserResponse: Codable {
    let user: User
}

struct BoxResponse: Codable {
    let box: Box
}

struct CardResponse: Codable {
    let card: Card
}

