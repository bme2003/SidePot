import SwiftUI

struct GroupFeedView: View {
    let groupId: UUID

    @EnvironmentObject var store: AppStore
    @State private var bets: [Bet] = []
    @State private var errorText: String?

    // UI state
    @State private var showPlusMenu = false
    @State private var showCreateBet = false
    @State private var showInvite = false

    private var group: Group? { store.groups.first(where: { $0.id == groupId }) }
    private var isOwner: Bool { group?.ownerId == store.me?.id }

    var body: some View {
        List {
            if let errorText {
                Text(errorText).foregroundStyle(.red)
            }

            if bets.isEmpty {
                Text("No bets yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(bets) { b in
                    NavigationLink {
                        BetDetailView(betId: b.id, groupId: groupId)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(b.title).font(.headline)
                            Text(b.status.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle(group?.name ?? "Group")
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        GroupAdminView(groupId: groupId)
                            .environmentObject(store)
                    } label: {
                        Text("Admin")
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPlusMenu = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                // Do NOT disable the button for lockout; we still want Invite to be available.
            }
        }
        .confirmationDialog(
            "What would you like to do?",
            isPresented: $showPlusMenu,
            titleVisibility: .visible
        ) {
            Button("Create Bet") {
                showCreateBet = true
            }
            .disabled(store.isLockedOut(in: groupId))

            Button("Invite") {
                showInvite = true
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            if store.isLockedOut(in: groupId) {
                Text("You must resolve your debt in this group before creating new bets. Invites are still allowed.")
            } else {
                Text("Choose an action for this group.")
            }
        }
        .sheet(isPresented: $showCreateBet) {
            CreateBetSheet(
                groupId: groupId,
                onCreated: { Task { await load() } }
            )
            .environmentObject(store)
        }
        .sheet(isPresented: $showInvite) {
            InviteGroupSheet(groupId: groupId)
                .environmentObject(store)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        errorText = nil
        do {
            await store.refreshGroups()
            bets = try await store.listBets(groupId: groupId)
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Could not load bets."
        }
    }
}
