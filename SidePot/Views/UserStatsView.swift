import SwiftUI

struct UserStatsView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var api = MockAPI.shared

    var body: some View {
        let debts = api.openDebts(for: store.me.id)
        let totalOwed = debts.reduce(0) { $0 + $1.amount.cents }

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.me.displayName).font(.title.weight(.bold))
                Text("@\(store.me.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Open debts").font(.caption).foregroundStyle(.secondary)
                    Text("\(debts.count)").font(.title3.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total owed").font(.caption).foregroundStyle(.secondary)
                    Text(Money(cents: totalOwed).dollarsString).font(.title3.weight(.semibold))
                }
            }
            .card()

            if store.isLockedOut() {
                Banner(title: "Restricted", detail: "Resolve open debts to create bets or place pledges.")
            } else {
                Banner(title: "Clear", detail: "No restrictions. You can participate normally.")
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Me")
    }
}
