//
//  Box.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import Foundation

struct Box: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let createdAt: String
}

struct BoxesResponse: Codable {
    let boxes: [Box]
}

