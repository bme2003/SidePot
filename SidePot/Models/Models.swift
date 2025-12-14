import Foundation

struct Group: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var createdAt: Date
}

struct BetOutcome: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var pot: Money
}

struct Bet: Codable, Identifiable, Hashable {
    let id: UUID
    let groupId: UUID

    var title: String
    var details: String
    var clarification: String?

    var lockAt: Date
    var resolveAt: Date

    var rule: Rule
    var status: Status

    var outcomes: [BetOutcome]
    var createdByUserId: UUID

    enum Rule: String, Codable, CaseIterable, Identifiable {
        case unanimousVote
        case creatorDecides
        case groupVote

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .unanimousVote: return "Unanimous vote"
            case .creatorDecides: return "Creator decides"
            case .groupVote: return "Group vote"
            }
        }
    }

    enum Status: String, Codable {
        case active
        case locked
        case settled
        case disputed
    }
}

struct Wager: Codable, Identifiable, Hashable {
    let id: UUID
    let betId: UUID
    let userId: UUID
    let outcomeId: UUID
    var amount: Money
    var createdAt: Date
}

struct Comment: Codable, Identifiable, Hashable {
    let id: UUID
    let betId: UUID
    let userId: UUID
    var authorName: String
    var body: String
    var createdAt: Date
    var reactions: [String:Int]
}

struct LedgerEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var createdAt: Date
    var title: String
    var detail: String
    var delta: Money // + or - (we store sign in cents)
}

struct UserProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
}
