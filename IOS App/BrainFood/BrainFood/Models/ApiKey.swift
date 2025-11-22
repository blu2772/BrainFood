//
//  ApiKey.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import Foundation

struct ApiKey: Codable, Identifiable {
    let id: String
    let keyPrefix: String
    let expiresAt: String
    let createdAt: String
    let lastUsedAt: String?
}

struct ApiKeyResponse: Codable {
    let key: String
    let keyPrefix: String
    let expiresAt: String
    let message: String
}

struct ApiKeysResponse: Codable {
    let keys: [ApiKey]
}

