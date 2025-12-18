import SwiftUI

struct BetDetailView: View {
    let betId: UUID
    let groupId: UUID

    @EnvironmentObject var store: AppStore
    @State private var bet: Bet?
    @State private var errorText: String?

    @State private var dollars = 5
    @State private var selectedOutcomeId: UUID?

    @State private var showResolve = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                if let errorText {
                    Text(errorText).foregroundStyle(.red)
                }

                if let bet {
                    
                    // Cacluate the pot
                    let totalPotCents = bet.outcomes.reduce(0) { $0 + $1.pot.cents }
                    let totalPotDollars = Double(totalPotCents) / 100.0
                    
                    BetHeaderCard(bet: bet, pot: totalPotDollars)

                    if bet.status == .settled {
                        SettledBanner()
                    }

                    Text("Pick an outcome")
                        .font(.headline)
                        .padding(.top, 2)

                    VStack(spacing: 10) {
                        ForEach(bet.outcomes) { o in
                            OutcomeCard(
                                title: o.title,
                                selected: selectedOutcomeId == o.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard !isLocked else { return }
                                selectedOutcomeId = o.id
                            }
                            .opacity(isLocked ? 0.9 : 1.0)
                        }
                    }

                    VStack(spacing: 10) {
                        PledgeCard(dollars: $dollars)
                            .opacity(isLocked ? 0.55 : 1.0)

                        Button(isLocked ? "Bet Locked" : "Place Pledge") {
                            Task { await pledge() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLocked || selectedOutcomeId == nil)

                        if canResolve {
                            Button("Resolve") { showResolve = true }
                                .buttonStyle(.bordered)
                                .disabled(isLocked) // hides sheet access when settled
                        }
                    }
                    .padding(.top, 8)

                } else {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding()
        }
        .navigationTitle("Bet")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh") { Task { await load() } }
            }
        }
        .sheet(isPresented: $showResolve) {
            NavigationStack {
                ResolveBetSheet(bet: bet) { outcomeId in
                    Task { await resolve(outcomeId: outcomeId) }
                }
            }
        }
        .task { await load() }
    }

    // MARK: - Permissions / Locking

    /// Locks after resolved; also locks if you want to enforce "locked after lockAt" here later.
    private var isLocked: Bool {
        guard let bet else { return true }
        return bet.status == .settled
    }

    /// Only show resolve if current user is the GROUP OWNER.
    /// If you'd rather allow bet creator too, change condition to:
    /// (meId == groupOwnerId || meId == bet.createdByUserId)
    private var canResolve: Bool {
        guard let meId = store.me?.id else { return false }
        guard let groupOwnerId = store.groups.first(where: { $0.id == groupId })?.ownerId else { return false }
        guard let bet else { return false }
        return meId == bet.createdByUserId && bet.status != .settled
    }

    // MARK: - Data

    private func load() async {
        errorText = nil
        do {
            // Ensure groups are current so group owner check works
            await store.refreshGroups()

            let list = try await store.listBets(groupId: groupId)
            bet = list.first(where: { $0.id == betId })

            if selectedOutcomeId == nil {
                selectedOutcomeId = bet?.outcomes.first?.id
            }
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Could not load bet."
        }
    }

    private func pledge() async {
        errorText = nil
        guard !isLocked else { return }
        guard let oid = selectedOutcomeId else { return }

        do {
            guard let bet = bet else { return }
            try await store.placeWager(groupId: bet.groupId, betId: betId, outcomeId: oid, dollars: dollars)
            await load()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Could not place pledge."
        }
    }

    private func resolve(outcomeId: UUID) async {
        errorText = nil
        guard canResolve else { return }

        do {
            try await store.resolveBet(betId: betId, winningOutcomeId: outcomeId)
            showResolve = false
            await load()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Could not resolve bet."
        }
    }
}

private struct SettledBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text("Bet settled")
                    .font(.subheadline.weight(.semibold))
                Text("Pledges and resolution are locked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BetHeaderCard: View {
    let bet: Bet
    let pot: Double

    var body: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(bet.title)
                    .font(.title2.weight(.bold))
                Spacer()
                StatusPill(text: bet.status.rawValue.capitalized)
            }
            
            Text(bet.details)
                .foregroundStyle(.secondary)
            

            HStack(spacing: 10) {
                Text(String(format: "Pot: $%.2f", pot)).font(.title3.weight(.bold))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Locks").font(.caption).foregroundStyle(.secondary)
                    Text(bet.lockAt, style: .date).font(.caption.weight(.semibold))
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct StatusPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }
}

private struct OutcomeCard: View {
    let title: String
    let selected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .semibold))
        }
        .padding()
        .background(selected ? .thinMaterial : .ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? Color.primary.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PledgeCard: View {
    @Binding var dollars: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pledge amount").font(.headline)
            Stepper(" $\(dollars)", value: $dollars, in: 1...50)
                .font(.body)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ResolveBetSheet: View {
    let bet: Bet?
    let onResolve: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: UUID?

    var body: some View {
        Form {
            if let bet {
                if bet.status == .settled {
                    Section {
                        Text("This bet is already settled.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Pick winner") {
                        ForEach(bet.outcomes) { o in
                            Button {
                                selected = o.id
                            } label: {
                                HStack {
                                    Text(o.title)
                                    Spacer()
                                    if selected == o.id { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                    Section {
                        Button("Resolve") {
                            if let selected { onResolve(selected) }
                        }
                        .disabled(selected == nil)
                    }
                }
            } else {
                Text("No bet loaded.")
            }
        }
        .navigationTitle("Resolve")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear { selected = bet?.outcomes.first?.id }
    }
}
