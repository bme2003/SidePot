import SwiftUI

struct DebtsView: View {
    let groupId: UUID

    @EnvironmentObject var store: AppStore
    @StateObject private var api = MockAPI.shared

    var body: some View {
        let debts = api.listDebts(groupId: groupId)

        List {
            Section {
                if debts.isEmpty {
                    Text("No debts recorded.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(debts) { d in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(api.displayName(d.fromUserId)) owes \(api.displayName(d.toUserId))")
                                    .font(.headline)
                                Spacer()
                                Pill(text: d.status == .open ? "OPEN" : "RESOLVED",
                                     systemImage: d.status == .open ? "exclamationmark.circle" : "checkmark.circle")
                            }

                            Text("Amount: \(d.amount.dollarsString)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if d.status == .open {
                                Button {
                                    api.resolveDebt(debtId: d.id, actingUserId: store.me.id)
                                } label: {
                                    Text("Mark resolved")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!canResolve(d))
                            } else if let t = d.resolvedAt {
                                Text("Resolved \(t, style: .date)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .card()
                        .padding(.vertical, 6)
                    }
                }
            } header: {
                Text("Debts")
            }

            Section {
                Text("Debts are virtual. Members with open debts cannot place new pledges or create new bets.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Debts")
    }

    private func canResolve(_ d: Debt) -> Bool {
        guard let g = api.getGroup(groupId) else { return false }
        return store.me.id == g.ownerId || store.me.id == d.toUserId
    }
}
