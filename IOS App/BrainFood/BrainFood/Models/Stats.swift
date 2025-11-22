//
//  Stats.swift
//  BrainFood
//
//  Created on 22.11.25.
//

import Foundation

struct DailyReview: Codable {
    let date: String
    let count: Int
}

struct BoxStats: Codable {
    let dueCount: Int
    let nextDue: String?
    let totalCards: Int
    let totalReviews: Int
    let totalLapses: Int
    let dailyReviews: [DailyReview]
}

struct StatsResponse: Codable {
    let stats: BoxStats
}

