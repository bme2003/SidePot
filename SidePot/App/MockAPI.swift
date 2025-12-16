import Foundation

@MainActor
final class MockAPI: ObservableObject {
    static let shared = MockAPI()
    private let saveFile = "sidepot_mock_db_v2.json"

    struct DB: Codable {
        var me: UserProfile
        var users: [UserProfile]
        var friends: [Friend]

        var groups: [Group]
        var invites: [PendingInvite]

        var bets: [Bet]
        var wagers: [Wager]
        var comments: [Comment]

        var debts: [Debt]
        var ledger: [LedgerEntry]
    }

    @Published private(set) var db: DB

    private init() {
        if let loaded: DB = Persistence.load(DB.self, from: saveFile) {
            self.db = loaded
        } else {
            let me = UserProfile(id: UUID(), username: "brody", displayName: "Brody")
            self.db = DB(
                me: me,
                users: [me],
                friends: [],
                groups: [],
                invites: [],
                bets: [],
                wagers: [],
                comments: [],
                debts: [],
                ledger: []
            )
            seed()
            persist()
        }
    }

    private func persist() { Persistence.save(db, to: saveFile) }

    private func seed() {
        let g = Group(
            id: UUID(),
            name: "Friends",
            createdAt: Date(),
            ownerId: db.me.id,
            memberIds: [db.me.id]
        )
        db.groups.append(g)

        db.ledger.append(
            LedgerEntry(
                id: UUID(),
                userId: db.me.id,
                createdAt: Date(),
                title: "Mock mode",
                detail: "All money is virtual and trust-based.",
                delta: Money(cents: 0)
            )
        )
    }

    // MARK: - Helpers

    func getMe() -> UserProfile { db.me }

    func user(for id: UUID) -> UserProfile? {
        db.users.first { $0.id == id }
    }

    func displayName(_ userId: UUID) -> String {
        user(for: userId)?.displayName ?? "Unknown"
    }

    func usernameExists(_ username: String) -> Bool {
        db.users.contains { $0.username.lowercased() == username.lowercased() }
    }

    func ensureUser(username: String, displayName: String) -> UserProfile {
        if let existing = db.users.first(where: { $0.username.lowercased() == username.lowercased() }) {
            return existing
        }
        let u = UserProfile(id: UUID(),
                            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines))
        db.users.append(u)
        persist()
        return u
    }

    // MARK: - Debt gating

    func openDebts(for userId: UUID) -> [Debt] {
        db.debts.filter { $0.fromUserId == userId && $0.status == .open }
    }

    func isLockedOut(userId: UUID) -> Bool {
        !openDebts(for: userId).isEmpty
    }

    // MARK: - Groups

    func listGroups() -> [Group] {
        db.groups.sorted { $0.createdAt > $1.createdAt }
    }

    func createGroup(name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let g = Group(id: UUID(),
                      name: clean.isEmpty ? "Untitled Group" : clean,
                      createdAt: Date(),
                      ownerId: db.me.id,
                      memberIds: [db.me.id])
        db.groups.insert(g, at: 0)
        persist()
    }

    func getGroup(_ groupId: UUID) -> Group? {
        db.groups.first { $0.id == groupId }
    }

    func upsertGroup(_ group: Group) {
        if let idx = db.groups.firstIndex(where: { $0.id == group.id }) {
            db.groups[idx] = group
        }
        persist()
    }

    func addMember(groupId: UUID, userId: UUID) {
        guard var g = getGroup(groupId) else { return }
        guard !g.memberIds.contains(userId) else { return }
        g.memberIds.append(userId)
        upsertGroup(g)
    }

    func removeMember(groupId: UUID, userId: UUID) {
        guard var g = getGroup(groupId) else { return }
        guard userId != g.ownerId else { return }
        g.memberIds.removeAll { $0 == userId }
        upsertGroup(g)
    }

    // MARK: - Friends

    func listFriends() -> [Friend] {
        db.friends.sorted { $0.createdAt > $1.createdAt }
    }

    func addFriend(username: String, displayName: String) {
        let u = ensureUser(username: username, displayName: displayName)
        if db.friends.contains(where: { $0.username.lowercased() == u.username.lowercased() }) { return }
        db.friends.insert(Friend(id: UUID(), username: u.username, displayName: u.displayName, createdAt: Date()), at: 0)
        persist()
    }

    func removeFriend(friendId: UUID) {
        db.friends.removeAll { $0.id == friendId }
        persist()
    }

    // MARK: - Invites (Contacts)

    func listInvites(groupId: UUID) -> [PendingInvite] {
        db.invites.filter { $0.groupId == groupId }.sorted { $0.createdAt > $1.createdAt }
    }

    func createInvite(groupId: UUID, contactName: String, contactIdentifier: String) {
        let inv = PendingInvite(id: UUID(),
                                groupId: groupId,
                                contactName: contactName,
                                contactIdentifier: contactIdentifier,
                                createdAt: Date())
        db.invites.insert(inv, at: 0)
        persist()
    }

    func deleteInvite(inviteId: UUID) {
        db.invites.removeAll { $0.id == inviteId }
        persist()
    }

    // MARK: - Bets

    func listBets(groupId: UUID) -> [Bet] {
        db.bets.filter { $0.groupId == groupId }.sorted { $0.lockAt < $1.lockAt }
    }

    func getBet(_ betId: UUID) -> Bet? {
        db.bets.first { $0.id == betId }
    }

    func upsertBet(_ bet: Bet) {
        if let idx = db.bets.firstIndex(where: { $0.id == bet.id }) {
            db.bets[idx] = bet
        }
        persist()
    }

    func createBet(groupId: UUID,
                   title: String,
                   details: String,
                   lockAt: Date,
                   resolveAt: Date,
                   rule: Bet.Rule,
                   outcomes: [String]) {
        // debt gating
        guard !isLockedOut(userId: db.me.id) else { return }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanOutcomes = outcomes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard cleanOutcomes.count >= 2 else { return }

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
            createdByUserId: db.me.id
        )

        db.bets.insert(bet, at: 0)
        persist()
    }

    func placeWager(betId: UUID, outcomeId: UUID, dollars: Int) {
        guard !isLockedOut(userId: db.me.id) else { return }
        guard var bet = getBet(betId) else { return }
        guard bet.status == .active else { return }
        guard Date() < bet.lockAt else { return }

        let cents = max(1, min(50, dollars)) * 100

        let w = Wager(id: UUID(),
                      betId: betId,
                      userId: db.me.id,
                      outcomeId: outcomeId,
                      amount: Money(cents: cents),
                      createdAt: Date())
        db.wagers.append(w)

        if let idx = bet.outcomes.firstIndex(where: { $0.id == outcomeId }) {
            bet.outcomes[idx].pot = Money(cents: bet.outcomes[idx].pot.cents + cents)
        }
        upsertBet(bet)

        db.ledger.append(
            LedgerEntry(id: UUID(),
                        userId: db.me.id,
                        createdAt: Date(),
                        title: "Pledge placed",
                        detail: "Bet: \(bet.title)",
                        delta: Money(cents: -cents))
        )
        persist()
    }

    func toggleDispute(betId: UUID) {
        guard var bet = getBet(betId) else { return }
        bet.status = (bet.status == .disputed) ? .active : .disputed
        upsertBet(bet)
    }

    // MARK: - Comments

    func listComments(betId: UUID) -> [Comment] {
        db.comments.filter { $0.betId == betId }.sorted { $0.createdAt < $1.createdAt }
    }

    func addComment(betId: UUID, body: String) {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let c = Comment(id: UUID(),
                        betId: betId,
                        userId: db.me.id,
                        authorName: db.me.displayName,
                        body: text,
                        createdAt: Date())
        db.comments.append(c)
        persist()
    }

    // MARK: - Debts

    func listDebts(groupId: UUID) -> [Debt] {
        db.debts.filter { $0.groupId == groupId }.sorted { $0.createdAt > $1.createdAt }
    }

    func resolveDebt(debtId: UUID, actingUserId: UUID) {
        guard let idx = db.debts.firstIndex(where: { $0.id == debtId }) else { return }
        let d = db.debts[idx]
        guard let g = getGroup(d.groupId) else { return }

        // Only group owner or creditor can mark resolved in MVP
        guard actingUserId == g.ownerId || actingUserId == d.toUserId else { return }

        db.debts[idx].status = .resolved
        db.debts[idx].resolvedAt = Date()

        db.ledger.append(
            LedgerEntry(id: UUID(),
                        userId: d.fromUserId,
                        createdAt: Date(),
                        title: "Debt resolved",
                        detail: "Resolved with \(displayName(d.toUserId))",
                        delta: Money(cents: 0))
        )
        db.ledger.append(
            LedgerEntry(id: UUID(),
                        userId: d.toUserId,
                        createdAt: Date(),
                        title: "Debt resolved",
                        detail: "Resolved with \(displayName(d.fromUserId))",
                        delta: Money(cents: 0))
        )
        persist()
    }

    // MARK: - Settlement

    func resolveBet(betId: UUID, winningOutcomeId: UUID) {
        guard var bet = getBet(betId) else { return }
        guard bet.status != .disputed else { return }
        guard bet.status != .settled else { return }

        let wagers = db.wagers.filter { $0.betId == betId }
        let totalPot = wagers.reduce(0) { $0 + $1.amount.cents }
        let winners = wagers.filter { $0.outcomeId == winningOutcomeId }
        let totalWinnerStake = winners.reduce(0) { $0 + $1.amount.cents }

        bet.status = .settled
        upsertBet(bet)

        // No winners: do nothing beyond ledger note
        guard totalWinnerStake > 0 else {
            db.ledger.append(LedgerEntry(id: UUID(),
                                         userId: db.me.id,
                                         createdAt: Date(),
                                         title: "Bet settled",
                                         detail: "No winners recorded.",
                                         delta: Money(cents: 0)))
            persist()
            return
        }

        // Compute payouts per winner
        struct Payout { let userId: UUID; let cents: Int }
        var payouts: [Payout] = []
        for w in winners {
            let payout = (totalPot * w.amount.cents) / totalWinnerStake
            payouts.append(Payout(userId: w.userId, cents: payout))
        }

        // Compute net per user (payout - stake)
        var stakeByUser: [UUID:Int] = [:]
        for w in wagers { stakeByUser[w.userId, default: 0] += w.amount.cents }

        var payoutByUser: [UUID:Int] = [:]
        for p in payouts { payoutByUser[p.userId, default: 0] += p.cents }

        let allUsers = Set(wagers.map { $0.userId })
        var netByUser: [UUID:Int] = [:]
        for u in allUsers {
            let net = (payoutByUser[u, default: 0] - stakeByUser[u, default: 0])
            netByUser[u] = net
        }

        // Create virtual debts: losers (negative net) owe winners (positive net)
        let winnersNet = netByUser.filter { $0.value > 0 }
        let losersNet = netByUser.filter { $0.value < 0 }

        let totalWinnerNet = winnersNet.values.reduce(0, +)
        guard totalWinnerNet > 0 else { persist(); return }

        for (loserId, negNet) in losersNet {
            let owedTotal = -negNet
            for (winnerId, posNet) in winnersNet {
                let share = (owedTotal * posNet) / totalWinnerNet
                if share <= 0 { continue }
                db.debts.append(
                    Debt(id: UUID(),
                         groupId: bet.groupId,
                         betId: bet.id,
                         fromUserId: loserId,
                         toUserId: winnerId,
                         amount: Money(cents: share),
                         status: .open,
                         createdAt: Date(),
                         resolvedAt: nil)
                )
            }
        }

        // Ledger notes for winners/losers (virtual)
        for (u, net) in netByUser {
            let entryTitle = net >= 0 ? "Bet result recorded" : "Bet result recorded"
            let entryDetail = "Bet: \(bet.title)"
            db.ledger.append(
                LedgerEntry(id: UUID(),
                            userId: u,
                            createdAt: Date(),
                            title: entryTitle,
                            detail: entryDetail,
                            delta: Money(cents: net))
            )
        }

        persist()
    }

    // MARK: - Ledger

    func listLedger(userId: UUID) -> [LedgerEntry] {
        db.ledger.filter { $0.userId == userId }.sorted { $0.createdAt > $1.createdAt }
    }
}
