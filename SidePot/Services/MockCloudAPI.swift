import Foundation
import CryptoKit

@MainActor
final class MockCloudAPI: AuthService, GroupsService, BetsService {

    struct Credential: Codable {
        let usernameLower: String
        let passwordHash: String
        let userId: UUID
    }

    struct DB: Codable {
        var users: [UserProfile] = []
        var credentials: [Credential] = []
        var sessions: [String: UUID] = [:]

        var groups: [Group] = []
        var invites: [Invite] = []

        var bets: [Bet] = []
        var wagers: [Wager] = []
        var debts: [Debt] = []
        var ledger: [LedgerEntry] = []
        var comments: [Comment] = []
    }

    private var db: DB
    private let saveFile = "sidepot_mock_cloud.json"

    init() {
        if let loaded: DB = Persistence.load(DB.self, from: saveFile) {
            db = loaded
        } else {
            db = DB()
            persist()
        }
    }

    private func persist() { Persistence.save(db, to: saveFile) }

    // MARK: - Auth

    func signUp(username: String, password: String, displayName: String) async throws -> Session {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let d = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty, !d.isEmpty else { throw SidePotError.validation("Username and display name are required.") }
        guard password.count >= 6 else { throw SidePotError.validation("Password must be at least 6 characters.") }

        let uLower = u.lowercased()
        if db.credentials.contains(where: { $0.usernameLower == uLower }) {
            throw SidePotError.usernameTaken
        }

        let user = UserProfile(id: UUID(), username: u, displayName: d)
        db.users.append(user)
        db.credentials.append(Credential(usernameLower: uLower, passwordHash: Self.hash(password), userId: user.id))

        let token = UUID().uuidString
        db.sessions[token] = user.id
        persist()
        return Session(token: token, userId: user.id)
    }

    func signIn(username: String, password: String) async throws -> Session {
        let uLower = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let cred = db.credentials.first(where: { $0.usernameLower == uLower }) else { throw SidePotError.invalidCredentials }
        guard cred.passwordHash == Self.hash(password) else { throw SidePotError.invalidCredentials }

        let token = UUID().uuidString
        db.sessions[token] = cred.userId
        persist()
        return Session(token: token, userId: cred.userId)
    }

    func me(token: String) async throws -> UserProfile {
        let uid = try requireUserId(token: token)
        guard let user = db.users.first(where: { $0.id == uid }) else { throw SidePotError.notFound }
        return user
    }

    // MARK: - Groups

    func listGroups(token: String) async throws -> [Group] {
        let uid = try requireUserId(token: token)
        return db.groups
            .filter { $0.memberIds.contains(uid) }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    func createGroup(token: String, name: String) async throws -> Group {
        let uid = try requireUserId(token: token)
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let g = Group(
            id: UUID(),
            name: clean.isEmpty ? "Untitled Group" : clean,
            createdAt: Date(),
            ownerId: uid,
            memberIds: [uid]
        )
        db.groups.insert(g, at: 0)
        persist()
        return g
    }

    func createInvite(token: String, groupId: UUID) async throws -> Invite {
        let uid = try requireUserId(token: token)
        guard let group = db.groups.first(where: { $0.id == groupId }) else { throw SidePotError.notFound }
        guard group.ownerId == uid else { throw SidePotError.forbidden }

        let inv = Invite(
            id: UUID(),
            groupId: groupId,
            code: Self.shortCode(),
            createdByUserId: uid,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(60 * 60 * 24 * 7),
            usedByUserId: nil
        )
        db.invites.insert(inv, at: 0)
        persist()
        return inv
    }

    func acceptInvite(token: String, code: String) async throws -> Group {
        let uid = try requireUserId(token: token)
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw SidePotError.validation("Invalid invite code.") }

        guard let i = db.invites.firstIndex(where: { $0.code == clean }) else { throw SidePotError.notFound }
        var inv = db.invites[i]
        guard inv.usedByUserId == nil else { throw SidePotError.validation("Invite already used.") }
        guard Date() < inv.expiresAt else { throw SidePotError.validation("Invite expired.") }

        guard let g = db.groups.firstIndex(where: { $0.id == inv.groupId }) else { throw SidePotError.notFound }
        if !db.groups[g].memberIds.contains(uid) {
            db.groups[g].memberIds.append(uid)
        }

        inv.usedByUserId = uid
        db.invites[i] = inv
        persist()
        return db.groups[g]
    }

    // MARK: - Bets

    func listBets(token: String, groupId: UUID) async throws -> [Bet] {
        let uid = try requireUserId(token: token)
        guard let group = db.groups.first(where: { $0.id == groupId }) else { throw SidePotError.notFound }
        guard group.memberIds.contains(uid) else { throw SidePotError.forbidden }

        return db.bets
            .filter { $0.groupId == groupId }
            .sorted(by: { $0.lockAt < $1.lockAt })
    }

    func createBet(
        token: String,
        groupId: UUID,
        title: String,
        details: String,
        lockAt: Date,
        resolveAt: Date,
        rule: Bet.Rule,
        outcomes: [String]
    ) async throws -> UUID {
        let uid = try requireUserId(token: token)
        guard let group = db.groups.first(where: { $0.id == groupId }) else { throw SidePotError.notFound }
        guard group.memberIds.contains(uid) else { throw SidePotError.forbidden }

        if hasOpenDebts(userId: uid, groupId: groupId) { throw SidePotError.validation("Resolve your debt in this group first.") }


        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanOutcomes = outcomes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard cleanOutcomes.count >= 2 else { throw SidePotError.validation("Add at least 2 outcomes.") }

        let bet = Bet(
            id: UUID(),
            groupId: groupId,
            title: cleanTitle.isEmpty ? "Untitled Bet" : cleanTitle,
            details: cleanDetails.isEmpty ? "No description." : cleanDetails,
            lockAt: lockAt,
            resolveAt: resolveAt,
            rule: rule,
            status: .active,
            outcomes: cleanOutcomes.map { BetOutcome(id: UUID(), title: $0, pot: .zero) },
            createdByUserId: uid
        )
        db.bets.insert(bet, at: 0)
        persist()
        return bet.id
    }

    func placeWager(token: String, betId: UUID, outcomeId: UUID, dollars: Int) async throws {
            let uid = try requireUserId(token: token)

            guard let betIdx = db.bets.firstIndex(where: { $0.id == betId }) else { throw SidePotError.notFound }
            var bet = db.bets[betIdx]

            let betGroupId = bet.groupId
            if hasOpenDebts(userId: uid, groupId: betGroupId) {
                throw SidePotError.validation("Resolve your debt in this group first.")
            }

            guard bet.status == .active else { throw SidePotError.validation("Bet is not active.") }
            guard Date() < bet.lockAt else { throw SidePotError.validation("Bet is locked.") }

            guard let group = db.groups.first(where: { $0.id == bet.groupId }) else { throw SidePotError.notFound }
            guard group.memberIds.contains(uid) else { throw SidePotError.forbidden }
            guard bet.outcomes.contains(where: { $0.id == outcomeId }) else { throw SidePotError.validation("Invalid outcome.") }

        let clamped = max(1, min(50, dollars))
        let cents = clamped * 100

        let w = Wager(
            id: UUID(),
            betId: betId,
            userId: uid,
            outcomeId: outcomeId,
            amount: Money(cents: cents),
            createdAt: Date()
        )
        db.wagers.append(w)

        if let oi = bet.outcomes.firstIndex(where: { $0.id == outcomeId }) {
            bet.outcomes[oi].pot = Money(cents: bet.outcomes[oi].pot.cents + cents)
        }
        db.bets[betIdx] = bet

        db.ledger.append(
            LedgerEntry(
                id: UUID(),
                userId: uid,
                createdAt: Date(),
                title: "Pledge placed",
                detail: "Bet: \(bet.title)",
                delta: Money(cents: -cents)
            )
        )

        persist()
    }

    func resolveBet(token: String, betId: UUID, winningOutcomeId: UUID) async throws {
        let uid = try requireUserId(token: token)
        guard let betIdx = db.bets.firstIndex(where: { $0.id == betId }) else { throw SidePotError.notFound }
        var bet = db.bets[betIdx]

        guard let group = db.groups.first(where: { $0.id == bet.groupId }) else { throw SidePotError.notFound }
        guard group.ownerId == uid || bet.createdByUserId == uid else { throw SidePotError.forbidden }

        guard bet.status != .settled else { return }
        guard bet.status != .disputed else { throw SidePotError.validation("Bet is disputed.") }
        guard bet.outcomes.contains(where: { $0.id == winningOutcomeId }) else { throw SidePotError.validation("Invalid outcome.") }

        let wagers = db.wagers.filter { $0.betId == betId }
        let totalPot = wagers.reduce(0) { $0 + $1.amount.cents }
        let winners = wagers.filter { $0.outcomeId == winningOutcomeId }
        let totalWinnerStake = winners.reduce(0) { $0 + $1.amount.cents }

        bet.status = .settled
        db.bets[betIdx] = bet

        guard totalPot > 0, totalWinnerStake > 0 else {
            persist()
            return
        }

        var payoutByUser: [UUID: Int] = [:]
        for w in winners {
            let payout = (totalPot * w.amount.cents) / totalWinnerStake
            payoutByUser[w.userId, default: 0] += payout
        }

        var stakeByUser: [UUID: Int] = [:]
        for w in wagers { stakeByUser[w.userId, default: 0] += w.amount.cents }

        let users = Set(wagers.map { $0.userId })
        var net: [UUID: Int] = [:]
        for u in users {
            net[u] = payoutByUser[u, default: 0] - stakeByUser[u, default: 0]
        }

        let winnersNet = net.filter { $0.value > 0 }
        let losersNet = net.filter { $0.value < 0 }
        let totalWinnerNet = winnersNet.values.reduce(0, +)

        if totalWinnerNet > 0 {
            for (loserId, negNet) in losersNet {
                var remaining = -negNet
                let sortedWinners = winnersNet.sorted(by: { $0.value > $1.value })

                for (idx, win) in sortedWinners.enumerated() {
                    if remaining <= 0 { break }
                    let winnerId = win.key
                    let pos = win.value

                    var share = ((-negNet) * pos) / totalWinnerNet
                    if share <= 0 { share = 1 }
                    if idx == sortedWinners.count - 1 { share = remaining }
                    share = min(share, remaining)

                    db.debts.append(
                        Debt(
                            id: UUID(),
                            groupId: bet.groupId,
                            betId: bet.id,
                            fromUserId: loserId,
                            toUserId: winnerId,
                            amount: Money(cents: share),
                            status: .open,
                            createdAt: Date(),
                            resolvedAt: nil
                        )
                    )

                    remaining -= share
                }
            }
        }

        for (u, delta) in net {
            db.ledger.append(
                LedgerEntry(
                    id: UUID(),
                    userId: u,
                    createdAt: Date(),
                    title: "Bet settled",
                    detail: "Bet: \(bet.title)",
                    delta: Money(cents: delta)
                )
            )
        }

        persist()
    }

    func listDebts(token: String, groupId: UUID) async throws -> [Debt] {
        let uid = try requireUserId(token: token)
        guard let group = db.groups.first(where: { $0.id == groupId }) else { throw SidePotError.notFound }
        guard group.memberIds.contains(uid) else { throw SidePotError.forbidden }

        return db.debts
            .filter { $0.groupId == groupId }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    func resolveDebt(token: String, debtId: UUID) async throws {
        let uid = try requireUserId(token: token)
        guard let idx = db.debts.firstIndex(where: { $0.id == debtId }) else { throw SidePotError.notFound }
        let d = db.debts[idx]

        guard let group = db.groups.first(where: { $0.id == d.groupId }) else { throw SidePotError.notFound }
        guard uid == group.ownerId || uid == d.toUserId else { throw SidePotError.forbidden }

        db.debts[idx].status = .resolved
        db.debts[idx].resolvedAt = Date()
        persist()
    }

    func listLedger(token: String, userId: UUID) async throws -> [LedgerEntry] {
        let uid = try requireUserId(token: token)
        guard uid == userId else { throw SidePotError.forbidden }

        return db.ledger
            .filter { $0.userId == userId }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    // MARK: - Helpers

    private func requireUserId(token: String) throws -> UUID {
        guard let uid = db.sessions[token] else { throw SidePotError.notSignedIn }
        return uid
    }

    private func hasOpenDebts(userId: UUID, groupId: UUID) -> Bool {
        db.debts.contains(where: { $0.groupId == groupId && $0.fromUserId == userId && $0.status == .open })
    }


    private static func hash(_ input: String) -> String {
        let data = Data(input.utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func shortCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars[Int.random(in: 0..<chars.count)] })
    }
    
    func removeMember(token: String, groupId: UUID, memberId: UUID) async throws {
        let uid = try requireUserId(token: token)
        guard let gi = db.groups.firstIndex(where: { $0.id == groupId }) else { throw SidePotError.notFound }
        let group = db.groups[gi]
        guard group.ownerId == uid else { throw SidePotError.forbidden }
        guard memberId != group.ownerId else { throw SidePotError.validation("Owner cannot be removed.") }

        db.groups[gi].memberIds.removeAll(where: { $0 == memberId })

        // Optional cleanup: remove unresolved debts involving the removed user in this group
        // (keeps demo predictable; remove this if you want debts to persist)
        db.debts.removeAll { d in
            d.groupId == groupId && (d.fromUserId == memberId || d.toUserId == memberId)
        }

        persist()
    }
}
