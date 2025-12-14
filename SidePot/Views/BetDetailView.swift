import SwiftUI

struct BetDetailView: View {
    let betId: UUID

    @EnvironmentObject var store: AppStore
    @StateObject private var api = MockAPI.shared

    @State private var bet: Bet?
    @State private var pick: BetOutcome?
    @State private var dollars: Int = 5

    @State private var commentDraft = ""
    @State private var comments: [Comment] = []
    @State private var wagers: [Wager] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let bet {
                    header(bet)
                    outcomes(bet)
                    pledgeBox(bet)
                    adminActions(bet)

                    Divider().padding(.vertical, 6)

                    commentsSection

                } else {
                    ProgressView().padding(.top, 30)
                }
            }
            .padding()
        }
        .navigationTitle("Bet")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
    }

    private func load() {
        bet = api.getBet(betId)
        comments = api.listComments(betId: betId)
        wagers = api.listWagers(betId: betId)
    }

    private func header(_ bet: Bet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(bet.title).font(.title2.weight(.bold))

            Text(bet.details).foregroundStyle(.secondary)

            if let clarification = bet.clarification, !clarification.isEmpty {
                Text("Clarification: \(clarification)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .card()
            }

            HStack(spacing: 8) {
                Pill(text: bet.status.rawValue.uppercased())
                Pill(text: bet.rule.displayName, systemImage: "checkmark.seal")
            }

            Text("Locks \(bet.lockAt, style: .relative) • Resolves \(bet.resolveAt, style: .relative)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func outcomes(_ bet: Bet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Outcomes").font(.headline)
            ForEach(bet.outcomes) { o in
                Button {
                    pick = o
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(o.title).font(.headline)
                            Text("Pot: \(o.pot.dollarsString)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if pick?.id == o.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                        }
                    }
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pledgeBox(_ bet: Bet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Place a pledge").font(.headline)

            Stepper("Amount: $\(dollars)", value: $dollars, in: 1...50)

            Button {
                guard let pick else { return }
                api.placeWager(betId: bet.id, outcomeId: pick.id, dollars: dollars)
                load()
                store.refreshBets(groupId: bet.groupId)
            } label: {
                Text("Pledge (mock)")
                    .frame(maxWidth: .infinity)
            }
            .disabled(pick == nil || bet.status != .active)
            .buttonStyle(.borderedProminent)

            if bet.status != .active {
                Text("Bet is not active. Pledges are locked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func adminActions(_ bet: Bet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Actions").font(.headline)

            Button {
                api.toggleDispute(betId: bet.id)
                load()
                store.refreshBets(groupId: bet.groupId)
            } label: {
                HStack {
                    Image(systemName: bet.status == .disputed ? "pause.circle.fill" : "pause.circle")
                    Text(bet.status == .disputed ? "Remove dispute" : "Flag dispute (pause payout)")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if bet.status != .settled {
                Text("Resolve (demo)")
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 6)

                ForEach(bet.outcomes) { o in
                    Button {
                        api.resolveBet(betId: bet.id, winningOutcomeId: o.id)
                        load()
                        store.refreshBets(groupId: bet.groupId)
                    } label: {
                        HStack {
                            Text("Resolve as")
                            Text(o.title).bold()
                            Spacer()
                            Image(systemName: "trophy.fill")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(bet.status == .disputed)
                    .buttonStyle(.borderedProminent)
                }

                if bet.status == .disputed {
                    Text("Disputed bets can’t be settled until dispute is removed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Settled ✅").foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Comments").font(.headline)

            HStack(spacing: 8) {
                TextField("Say something…", text: $commentDraft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button {
                    api.addComment(betId: betId, body: commentDraft)
                    commentDraft = ""
                    load()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ForEach(comments) { c in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(c.authorName).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(c.createdAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(c.body)

                    HStack(spacing: 8) {
                        reactionButton(c, "😂")
                        reactionButton(c, "🔥")
                        reactionButton(c, "✅")
                        Spacer()
                        if !c.reactions.isEmpty {
                            Text(c.reactions.map { "\($0.key)\($0.value)" }.sorted().joined(separator: "  "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .card()
            }
        }
    }

    private func reactionButton(_ c: Comment, _ emoji: String) -> some View {
        Button {
            api.react(commentId: c.id, emoji: emoji)
            load()
        } label: {
            Text(emoji)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(.thinMaterial)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
