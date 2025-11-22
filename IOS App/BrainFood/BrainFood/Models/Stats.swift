import Foundation

struct BoxStats: Codable {
    let dueCount: Int
    let nextDue: Date?
    let totalCards: Int
    let totalReviews: Int
    let totalLapses: Int
    let recentReviews: Int
}
