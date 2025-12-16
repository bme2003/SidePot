import SwiftUI

struct GroupFeedView: View {
    let groupId: UUID

    @EnvironmentObject var store: AppStore
    @StateObject private var api = MockAPI.shared

    @State private var group: Group?
    @State private var bets: [Bet] = []
    @State private var showCreateBet = false

    var body: some View {
        VStack(spacing: 12) {
            if let group {
                header(group)

                if store.isLockedOut() {
                    Banner(
                        title: "Participation restricted",
                        detail: "You have unresolved debts. You can still view bets and comments."
                    )
                    .padding(.horizontal)
                }

                List {
                    Section {
                        ForEach(bets) { bet in
                            NavigationLink {
                                BetDetailView(betId: bet.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(bet.title).font(.headline)

                                    HStack(spacing: 8) {
                                        Pill(text: bet.status.rawValue.uppercased())
                                        Pill(text: bet.rule.displayName, systemImage: "checkmark.seal")
                                    }

                                    Text("Locks \(bet.lockAt, style: .relative)  •  Resolves \(bet.resolveAt, style: .relative)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    } header: {
                        Text("Bets")
                    }
                }
            } else {
                ProgressView().padding()
            }
        }
        .navigationTitle(group?.name ?? "Group")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    GroupMembersView(groupId: groupId)
                } label: {
                    Image(systemName: "person.2.fill")
                }

                Button {
                    showCreateBet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(store.isLockedOut())
            }
        }
        .sheet(isPresented: $showCreateBet) {
            CreateBetSheet(isPresented: $showCreateBet, groupId: groupId)
                .environmentObject(store)
        }
        .onAppear { reload() }
    }

    private func reload() {
        group = api.getGroup(groupId)
        bets = api.listBets(groupId: groupId)
    }

    private func header(_ group: Group) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SectionHeader(title: group.name, subtitle: "\(group.memberIds.count) members")
                Spacer()
                NavigationLink {
                    DebtsView(groupId: groupId)
                } label: {
                    Pill(text: "Debts", systemImage: "exclamationmark.circle")
                }
            }
            .card()
            .padding(.horizontal)
        }
    }
}
