import Foundation

@MainActor
final class AppStore: ObservableObject {

    @Published var session: Session?
    @Published var me: UserProfile?
    @Published var groups: [Group] = []

    // Per-group lockout
    @Published private(set) var lockedOutGroupIds: Set<UUID> = []

    private let auth: AuthService
    private let groupsSvc: GroupsService
    private let betsSvc: BetsService
    private let sessionStore: SessionStore

    init(
        auth: AuthService,
        groups: GroupsService,
        bets: BetsService,
        sessionStore: SessionStore
    ) {
        self.auth = auth
        self.groupsSvc = groups
        self.betsSvc = bets
        self.sessionStore = sessionStore
    }

    var isSignedIn: Bool { session != nil }

    func isLockedOut(in groupId: UUID) -> Bool {
        lockedOutGroupIds.contains(groupId)
    }

    func restoreSession() async {
        guard let token = sessionStore.loadToken() else { return }
        do {
            let user = try await auth.me(token: token)
            session = Session(token: token, userId: user.id)
            me = user
            groups = try await groupsSvc.listGroups(token: token)
            await refreshLockouts()
        } catch {
            sessionStore.clear()
            session = nil
            me = nil
            groups = []
            lockedOutGroupIds = []
        }
    }

    func signUp(username: String, password: String, displayName: String) async throws {
        let s = try await auth.signUp(username: username, password: password, displayName: displayName)
        sessionStore.saveToken(s.token)
        session = s
        me = try await auth.me(token: s.token)
        groups = try await groupsSvc.listGroups(token: s.token)
        await refreshLockouts()
    }

    func signIn(username: String, password: String) async throws {
        let s = try await auth.signIn(username: username, password: password)
        sessionStore.saveToken(s.token)
        session = s
        me = try await auth.me(token: s.token)
        groups = try await groupsSvc.listGroups(token: s.token)
        await refreshLockouts()
    }

    func signOut() {
        sessionStore.clear()
        session = nil
        me = nil
        groups = []
        lockedOutGroupIds = []
    }

    // MARK: - Groups

    func refreshGroups() async {
        guard let token = session?.token else { return }
        groups = (try? await groupsSvc.listGroups(token: token)) ?? []
        await refreshLockouts()
    }

    func createGroup(name: String) async throws {
        guard let token = session?.token else { throw SidePotError.notSignedIn }
        _ = try await groupsSvc.createGroup(token: token, name: name)
        groups = try await groupsSvc.listGroups(token: token)
        await refreshLockouts()
    }

    func createInvite(groupId: UUID) async throws -> Invite {
        guard let token = session?.token else { throw SidePotError.notSignedIn }
        return try await groupsSvc.createInvite(token: token, groupId: groupId)
    }

    func acceptInvite(code: String) async throws {
        guard let token = session?.token else { throw SidePotError.notSignedIn }
        _ = try await groupsSvc.acceptInvite(token: token, code: code)
        groups = try await groupsSvc.listGroups(token: token)
        await refreshLockouts()
    }

    /// Mock-only: remove member (keeps protocols unchanged)
    func removeMember(groupId: UUID, memberId: UUID) async throws {
        guard let token = session?.token else { throw SidePotError.notSignedIn }
        guard let cloud = groupsSvc as? MockCloudAPI else {
            throw SidePotError.validation("Remove member is not available in this build.")
        }
        try await cloud.removeMember(token: token, groupId: groupId, memberId: memberId)
        groups = try await groupsSvc.listGroups(token: token)
        await refreshLockouts()
    }

    // MARK: - Bets

    func listBets(groupId: UUID) async throws -> [Bet] {
        guard let token = session?.token else { throw SidePotError.notSignedIn }
        return try await betsSvc.listBets(token: token, groupId: groupId)
    }

    func createBet(
        groupId: UUID,
        title: String,
        details: String,
        lockAt: Date,
        resolveAt: Date,
        rule: Bet.Rule,
        outcomes: [String]
    ) async throws -> UUID {
        guard let token = session?.token else { throw SidePotError.notSignedIn }
        if isLockedOut(in: groupId) { throw SidePotError.validation("Resolve your debt in this group before creating a new bet.") }

        let id = try await betsSvc.createBet(
            token: token,
            groupId: groupId,
            title: title,
            details: details,
            lockAt: lockAt,
            resolveAt: resolveAt,
            rule: rule,
            outcomes: outcomes
        )
        await refreshLockouts()
        return id
    }

    // IMPORTANT: per-group lockout requires groupId here
    func placeWager(groupId: UUID, betId: UUID, outcomeId: UUID, dollars: Int) async throws {
        guard let token = session?.token else { throw SidePotError.notSignedIn }
        if isLockedOut(in: groupId) { throw SidePotError.validation("Resolve your debt in this group before placing pledges.") }

        try await betsSvc.placeWager(token: token, betId: betId, outcomeId: outcomeId, dollars: dollars)
        await refreshLockouts()
    }

    func resolveBet(betId: UUID, winningOutcomeId: UUID) async throws {
        guard let token = session?.token else { throw SidePotError.notSignedIn }
        try await betsSvc.resolveBet(token: token, betId: betId, winningOutcomeId: winningOutcomeId)
        await refreshLockouts()
    }

    // MARK: - Activity

    func listMyActivity() async throws -> [LedgerEntry] {
        guard let token = session?.token, let meId = me?.id else { throw SidePotError.notSignedIn }
        return try await betsSvc.listLedger(token: token, userId: meId)
    }

    // MARK: - Debts / Balance

    func listDebts(groupId: UUID) async throws -> [Debt] {
        guard let token = session?.token else { throw SidePotError.notSignedIn }
        return try await betsSvc.listDebts(token: token, groupId: groupId)
    }

    func resolveDebt(debtId: UUID) async throws {
        guard let token = session?.token else { throw SidePotError.notSignedIn }
        try await betsSvc.resolveDebt(token: token, debtId: debtId)
        await refreshLockouts()
    }

    func refreshLockouts() async {
        guard session != nil, let meId = me?.id else { lockedOutGroupIds = []; return }

        do {
            guard let token = session?.token else { lockedOutGroupIds = []; return }
            var locked = Set<UUID>()

            for g in groups {
                let debts = try await betsSvc.listDebts(token: token, groupId: g.id)
                let owesHere = debts.contains(where: { $0.status == .open && $0.fromUserId == meId })
                if owesHere { locked.insert(g.id) }
            }

            lockedOutGroupIds = locked
        } catch {
            lockedOutGroupIds = []
        }
    }

    // Optional helper you previously used
    func totalsWonLostCents() async throws -> (won: Int, lost: Int) {
        let entries = try await listMyActivity()
        let settled = entries.filter { $0.title == "Bet settled" }

        let won = settled.filter { $0.delta.cents > 0 }.reduce(0) { $0 + $1.delta.cents }
        let lost = settled.filter { $0.delta.cents < 0 }.reduce(0) { $0 + (-$1.delta.cents) }

        return (won, lost)
    }
    
    func listMyOpenDebts() async throws -> [Debt] {
        guard let token = session?.token, let meId = me?.id else { throw SidePotError.notSignedIn }

        var results: [Debt] = []
        for g in groups {
            let debts = try await betsSvc.listDebts(token: token, groupId: g.id)
            results.append(contentsOf: debts.filter { $0.status == .open && $0.fromUserId == meId })
        }

        return results.sorted(by: { $0.createdAt > $1.createdAt })
    }

    func totalOpenDebtCents() async throws -> Int {
        let debts = try await listMyOpenDebts()
        return debts.reduce(0) { $0 + $1.amount.cents }
    }
}
