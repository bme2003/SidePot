import Foundation

@MainActor
final class MockAPI: ObservableObject {
    static let shared = MockAPI()

    private let saveFile = "sidepot_mock_db.json"

    struct DB: Codable {
        var me: UserProfile
        var groups: [Group]
        var bets: [Bet]
        var wagers: [Wager]
        var comments: [Comment]
        var ledger: [LedgerEntry]
    }

    @Published private(set) var db: DB

    private init() {
        if let loaded: DB = Persistence.load(DB.self, from: saveFile) {
            self.db = loaded
        } else {
            let me = UserProfile(id: UUID(), displayName: "Brody")
            self.db = DB(
                me: me,
                groups: [],
                bets: [],
                wagers: [],
                comments: [],
                ledger: []
            )
            seedIfEmpty()
            persist()
        }
    }

    private func persist() {
        Persistence.save(db, to: saveFile)
    }

    private func seedIfEmpty() {
        guard db.groups.isEmpty else { return }

        let g1 = Group(id: UUID(), name: "The Last Men Standing (Friends)", createdAt: Date())
        db.groups.append(g1)

        let bet = Bet(
            id: UUID(),
            groupId: g1.id,
            title: "Does Xavier get a girlfriend by March 31?",
            details: "Friendly wager. Keep it civil. 🍀",
            clarification: "Counts if it’s official + acknowledged by both.",
            lockAt: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            resolveAt: Calendar.current.date(byAdding: .day, value: 14, to: Date())!,
            rule: .groupVote,
            status: .active,
            outcomes: [
                BetOutcome(id: UUID(), title: "Yes", pot: .zero),
                BetOutcome(id: UUID(), title: "No", pot: .zero)
            ],
            createdByUserId: db.me.id
        )
        db.bets.append(bet)

        db.ledger.append(
            LedgerEntry(
                id: UUID(),
                userId: db.me.id,
                createdAt: Date(),
                title: "Welcome to SidePot",
                detail: "This is mock mode (no real money).",
                delta: Money(cents: 0)
            )
        )
    }

    // MARK: - Read

    func getMe() -> UserProfile { db.me }

    func listGroups() -> [Group] {
        db.groups.sorted { $0.createdAt > $1.createdAt }
    }

    func listBets(groupId: UUID) -> [Bet] {
        db.bets
            .filter { $0.groupId == groupId }
            .sorted { $0.lockAt < $1.lockAt }
    }

    func getBet(_ betId: UUID) -> Bet? {
        db.bets.first { $0.id == betId }
    }

    func listComments(betId: UUID) -> [Comment] {
        db.comments
            .filter { $0.betId == betId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func listLedger(userId: UUID) -> [LedgerEntry] {
        db.ledger
            .filter { $0.userId == userId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func listWagers(betId: UUID) -> [Wager] {
        db.wagers.filter { $0.betId == betId }
    }

    // MARK: - Mutations

    func createGroup(name: String) {
        let g = Group(id: UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: Date())
        db.groups.insert(g, at: 0)
        persist()
    }

    func createBet(groupId: UUID,
                   title: String,
                   details: String,
                   clarification: String?,
                   lockAt: Date,
                   resolveAt: Date,
                   rule: Bet.Rule,
                   outcomes: [String]) {
        let cleanOutcomes = outcomes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard cleanOutcomes.count >= 2 else { return }

        let bet = Bet(
            id: UUID(),
            groupId: groupId,
            title: title,
            details: details,
            clarification: clarification?.isEmpty == true ? nil : clarification,
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
        guard var bet = getBet(betId) else { return }
        guard bet.status == .active else { return }
        guard Date() < bet.lockAt else { return }

        let cents = max(1, min(50, dollars)) * 100
        let w = Wager(id: UUID(), betId: betId, userId: db.me.id, outcomeId: outcomeId, amount: Money(cents: cents), createdAt: Date())
        db.wagers.append(w)

        // update pot
        if let idx = bet.outcomes.firstIndex(where: { $0.id == outcomeId }) {
            bet.outcomes[idx].pot = Money(cents: bet.outcomes[idx].pot.cents + cents)
        }
        upsertBet(bet)

        db.ledger.append(
            LedgerEntry(
                id: UUID(),
                userId: db.me.id,
                createdAt: Date(),
                title: "Pledged \(Money(cents: cents).dollarsString)",
                detail: "Bet: \(bet.title)",
                delta: Money(cents: -cents)
            )
        )
        persist()
    }

    func toggleDispute(betId: UUID) {
        guard var bet = getBet(betId) else { return }
        bet.status = (bet.status == .disputed) ? .active : .disputed
        upsertBet(bet)
        persist()
    }

    func addComment(betId: UUID, body: String) {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let c = Comment(
            id: UUID(),
            betId: betId,
            userId: db.me.id,
            authorName: db.me.displayName,
            body: text,
            createdAt: Date(),
            reactions: [:]
        )
        db.comments.append(c)
        persist()
    }

    func react(commentId: UUID, emoji: String) {
        guard let idx = db.comments.firstIndex(where: { $0.id == commentId }) else { return }
        db.comments[idx].reactions[emoji, default: 0] += 1
        persist()
    }

    /// Settles the bet by distributing winnings proportionally among users who chose the winning outcome.
    /// In mock mode, we just write ledger entries.
    func resolveBet(betId: UUID, winningOutcomeId: UUID) {
        guard var bet = getBet(betId) else { return }
        guard bet.status != .disputed else { return }
        guard bet.status != .settled else { return }

        // lock if past lockAt
        if Date() >= bet.lockAt { bet.status = .locked }

        let wagers = db.wagers.filter { $0.betId == betId }
        let totalPot = wagers.reduce(0) { $0 + $1.amount.cents }

        let winners = wagers.filter { $0.outcomeId == winningOutcomeId }
        let totalWinnerStake = winners.reduce(0) { $0 + $1.amount.cents }

        // If no winners, nobody gets paid. (Could roll over or refund in later version.)
        if totalWinnerStake == 0 {
            bet.status = .settled
            upsertBet(bet)
            db.ledger.append(
                LedgerEntry(id: UUID(), userId: db.me.id, createdAt: Date(),
                            title: "Settled (no winners)",
                            detail: "Bet: \(bet.title)",
                            delta: Money(cents: 0))
            )
            persist()
            return
        }

        // payout each winner: floor(totalPot * (stake / totalWinnerStake))
        // remainder pennies stay “platform dust” in mock mode
        for w in winners {
            let payout = (totalPot * w.amount.cents) / totalWinnerStake
            db.ledger.append(
                LedgerEntry(
                    id: UUID(),
                    userId: w.userId,
                    createdAt: Date(),
                    title: "Won \(Money(cents: payout).dollarsString)",
                    detail: "Bet: \(bet.title)",
                    delta: Money(cents: payout)
                )
            )
        }

        bet.status = .settled
        upsertBet(bet)
        persist()
    }

    // MARK: - Helpers

    private func upsertBet(_ bet: Bet) {
        if let idx = db.bets.firstIndex(where: { $0.id == bet.id }) {
            db.bets[idx] = bet
        }
    }
}
