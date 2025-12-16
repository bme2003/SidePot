import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var store: AppStore
    @State private var showCreate = false

    var body: some View {
        VStack(spacing: 12) {
            if store.isLockedOut() {
                Banner(
                    title: "Participation restricted",
                    detail: "You have unresolved debts. Resolve them to place pledges or create bets."
                )
                .padding(.horizontal)
            }

            List {
                ForEach(store.groups) { g in
                    NavigationLink {
                        GroupFeedView(groupId: g.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(g.name).font(.headline)
                            Text("\(g.memberIds.count) members")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Groups")
        .toolbar {
            Button(action: { showCreate = true }) {
                Image(systemName: "plus.circle.fill")
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateGroupSheet(isPresented: $showCreate)
                .environmentObject(store)
        }
        .onAppear { store.refreshAll() }
    }
}
