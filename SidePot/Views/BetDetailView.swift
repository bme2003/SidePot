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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let bet {
                    header(bet)
                    outcomes(bet)
                    pledgeBox(bet)
                    settlementBox(bet)
                    commentsBox
                } else {
                    ProgressView().padding(.top, 30)
                }
            }
            .padding()
        }
        .navigationTitle("Bet")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { load() }
    }

    private func load() {
        bet = api.getBet(betId)
        comments = api.listComments(betId: betId)
    }

    private func header(_ bet: Bet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(bet.title).font(.title2.weight(.bold))
            Text(bet.details).foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Pill(text: bet.status.rawValue.uppercased())
                Pill(text: bet.rule.displayName, systemImage: "checkmark.seal")
            }

            Text("Locks \(bet.lockAt, style: .relative)  •  Resolves \(bet.resolveAt, style: .relative)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.isLockedOut() {
                Banner(
                    title: "Participation restricted",
                    detail: "You have unresolved debts. You cannot place new pledges."
                )
            }
        }
        .card()
    }

    private func outcomes(_ bet: Bet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Outcomes", subtitle: "Pick one before lock time.")
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
                        }
                    }
                    .padding(12)
                    .background(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.corner)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.corner))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pledgeBox(_ bet: Bet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Pledge", subtitle: "Virtual and trust-based.")
            Stepper("Amount: \(dollars)", value: $dollars, in: 1...50)

            Button {
                guard let pick else { return }
                api.placeWager(betId: bet.id, outcomeId: pick.id, dollars: dollars)
                load()
            } label: {
                Text("Place pledge")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isLockedOut() || pick == nil || bet.status != .active)

            if bet.status != .active {
                Text("Pledges are closed for this bet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func settlementBox(_ bet: Bet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Settlement", subtitle: "Creates virtual debts for losers until resolved.")

            Button {
                api.toggleDispute(betId: bet.id)
                load()
            } label: {
                HStack {
                    Image(systemName: bet.status == .disputed ? "pause.circle.fill" : "pause.circle")
                    Text(bet.status == .disputed ? "Remove dispute" : "Flag dispute")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if bet.status != .settled {
                ForEach(bet.outcomes) { o in
                    Button {
                        api.resolveBet(betId: bet.id, winningOutcomeId: o.id)
                        load()
                    } label: {
                        HStack {
                            Text("Resolve as \(o.title)")
                            Spacer()
                            Image(systemName: "trophy.fill")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(bet.status == .disputed)
                }
            } else {
                Text("This bet is settled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var commentsBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Comments", subtitle: nil)

            HStack(spacing: 8) {
                TextField("Write a comment", text: $commentDraft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button {
                    api.addComment(betId: betId, body: commentDraft)
                    commentDraft = ""
                    load()
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ForEach(comments) { c in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(c.authorName).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(c.createdAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(c.body)
                }
                .card()
            }
        }
    }
}
