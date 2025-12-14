import SwiftUI

struct GroupFeedView: View {
    @EnvironmentObject var store: AppStore
    let group: Group

    @State private var showCreateBet = false
    @State private var filter: Filter = .active

    enum Filter: String, CaseIterable, Identifiable {
        case active = "Active"
        case settled = "Settled"
        var id: String { rawValue }
    }

    var filteredBets: [Bet] {
        switch filter {
        case .active: return store.bets.filter { $0.status != .settled }
        case .settled: return store.bets.filter { $0.status == .settled }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            List {
                ForEach(filteredBets) { bet in
                    NavigationLink {
                        BetDetailView(betId: bet.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(bet.title).font(.headline)

                            HStack(spacing: 8) {
                                Pill(text: bet.status.rawValue.uppercased())
                                Pill(text: bet.rule.displayName, systemImage: "checkmark.seal")
                            }

                            Text("Locks \(bet.lockAt, style: .relative) • Resolves \(bet.resolveAt, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .toolbar {
            Button {
                showCreateBet = true
            } label: {
                Image(systemName: "plus.circle.fill")
            }
        }
        .sheet(isPresented: $showCreateBet) {
            CreateBetSheet(isPresented: $showCreateBet, group: group)
                .environmentObject(store)
        }
        .onAppear {
            store.refreshBets(groupId: group.id)
        }
    }
}
