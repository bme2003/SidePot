import SwiftUI

struct UserStatsView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var api = MockAPI.shared

    var body: some View {
        let wagers = api.db.wagers.filter { $0.userId == store.me.id }
        let ledger = api.listLedger(userId: store.me.id)

        let totalPledged = wagers.reduce(0) { $0 + $1.amount.cents }
        let totalDelta = ledger.reduce(0) { $0 + $1.delta.cents }

        VStack(alignment: .leading, spacing: 14) {
            Text(store.me.displayName)
                .font(.title.weight(.bold))

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total pledged").font(.caption).foregroundStyle(.secondary)
                    Text(Money(cents: totalPledged).dollarsString).font(.title3.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Net (mock)").font(.caption).foregroundStyle(.secondary)
                    Text(Money(cents: abs(totalDelta)).dollarsString)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(totalDelta >= 0 ? .green : .red)
                }
            }
            .card()

            Text("Tip: Create a new group/bet to stress-test the flows.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .card()

            Spacer()
        }
        .padding()
        .navigationTitle("Me")
    }
}
