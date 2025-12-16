import Foundation

// MARK: - Users

struct UserProfile: Codable, Identifiable, Hashable {
    let id: UUID
    var username: String
    var displayName: String
}

struct Friend: Codable, Identifiable, Hashable {
    let id: UUID
    var username: String
    var displayName: String
    var createdAt: Date
}

// MARK: - Groups

struct Group: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var createdAt: Date
    var ownerId: UUID
    var memberIds: [UUID]
}

struct PendingInvite: Codable, Identifiable, Hashable {
    let id: UUID
    let groupId: UUID
    var contactName: String
    var contactIdentifier: String
    var createdAt: Date
}

// MARK: - Money

struct Money: Codable, Hashable, Comparable {
    var cents: Int
    init(cents: Int) { self.cents = cents }
    static func < (lhs: Money, rhs: Money) -> Bool { lhs.cents < rhs.cents }
    static var zero: Money { .init(cents: 0) }

    var dollarsString: String {
        String(format: "$%.2f", Double(cents) / 100.0)
    }
}

// MARK: - Bets

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

    var lockAt: Date
    var resolveAt: Date

    var rule: Rule
    var status: Status

    var outcomes: [BetOutcome]
    var createdByUserId: UUID

    enum Rule: String, Codable, CaseIterable, Identifiable {
        case unanimousVote, creatorDecides, groupVote
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .unanimousVote: return "Unanimous vote"
            case .creatorDecides: return "Owner decides"
            case .groupVote: return "Group vote"
            }
        }
    }

    enum Status: String, Codable {
        case active, locked, settled, disputed
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

// MARK: - Trust Debts

struct Debt: Codable, Identifiable, Hashable {
    let id: UUID
    let groupId: UUID
    let betId: UUID
    let fromUserId: UUID
    let toUserId: UUID
    var amount: Money
    var status: Status
    var createdAt: Date
    var resolvedAt: Date?

    enum Status: String, Codable { case open, resolved }
}

// MARK: - Social + Ledger

struct Comment: Codable, Identifiable, Hashable {
    let id: UUID
    let betId: UUID
    let userId: UUID
    var authorName: String
    var body: String
    var createdAt: Date
}

struct LedgerEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var createdAt: Date
    var title: String
    var detail: String
    var delta: Money
}
