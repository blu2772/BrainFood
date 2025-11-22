//
//  User.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import Foundation

struct User: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let createdAt: String
}

struct AuthResponse: Codable {
    let user: User
    let token: String
}

