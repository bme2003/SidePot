import SwiftUI

struct LedgerView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var api = MockAPI.shared

    var body: some View {
        let entries = api.listLedger(userId: store.me.id)

        List {
            ForEach(entries) { e in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(e.title).font(.headline)
                        Spacer()
                        Text(deltaString(e.delta.cents))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(e.delta.cents >= 0 ? .green : .red)
                    }
                    Text(e.detail).font(.caption).foregroundStyle(.secondary)
                    Text(e.createdAt, style: .date).font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Ledger")
    }

    private func deltaString(_ cents: Int) -> String {
        let absCents = abs(cents)
        let money = Money(cents: absCents).dollarsString
        return cents >= 0 ? "+\(money)" : "-\(money)"
    }
}
