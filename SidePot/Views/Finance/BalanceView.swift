import SwiftUI

struct BalanceView: View {
    @EnvironmentObject var store: AppStore

    @State private var openDebts: [Debt] = []
    @State private var openDebtTotalCents: Int = 0
    @State private var wonCents: Int = 0
    @State private var lostCents: Int = 0
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let errorText {
                    Text(errorText).foregroundStyle(.red)
                }

                SummaryCards(
                    openDebt: Money(cents: openDebtTotalCents),
                    won: Money(cents: wonCents),
                    lost: Money(cents: lostCents)
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("You Owe")
                        .font(.headline)
                        .padding(.horizontal, 4)

                    if openDebts.isEmpty {
                        BalanceEmptyState()
                    } else {
                        VStack(spacing: 10) {
                            ForEach(openDebts) { d in
                                DebtCard(debt: d)
                            }
                        }
                    }
                }
                .padding(.top, 4)

                Spacer(minLength: 24)
            }
            .padding()
        }
        .navigationTitle("Balance")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh") { Task { await load() } }
            }
        }
        .task { await load() }
    }

    private func load() async {
        errorText = nil
        do {
            await store.refreshGroups()

            openDebts = try await store.listMyOpenDebts()
            openDebtTotalCents = try await store.totalOpenDebtCents()

            let totals = try await store.totalsWonLostCents()
            wonCents = totals.won
            lostCents = totals.lost
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Could not load balance."
        }
    }
}

private struct SummaryCards: View {
    let openDebt: Money
    let won: Money
    let lost: Money

    var body: some View {
        VStack(spacing: 10) {
            StatCard(
                title: "Open Debt",
                value: openDebt.dollarsString,
                subtitle: "What you currently owe",
                systemImage: "exclamationmark.triangle.fill"
            )

            HStack(spacing: 10) {
                StatCard(
                    title: "Total Won",
                    value: won.dollarsString,
                    subtitle: "From settled bets",
                    systemImage: "arrow.up.circle.fill",
                    compact: true
                )
                StatCard(
                    title: "Total Lost",
                    value: lost.dollarsString,
                    subtitle: "From settled bets",
                    systemImage: "arrow.down.circle.fill",
                    compact: true
                )
            }
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack {
                Image(systemName: systemImage)
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
            }
            Text(value)
                .font(compact ? .title3.weight(.bold) : .title2.weight(.bold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BalanceEmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 28))
            Text("All clear.")
                .font(.headline)
            Text("No open debts right now.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct DebtCard: View {
    let debt: Debt

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("You owe \(debt.amount.dollarsString)")
                    .font(.headline)
                Text("Status: \(debt.status.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
