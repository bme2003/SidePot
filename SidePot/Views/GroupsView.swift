import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var store: AppStore
    @State private var showCreate = false

    var body: some View {
        List {
            ForEach(store.groups) { g in
                NavigationLink {
                    GroupFeedView(group: g)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(g.name)
                            .font(.headline)

                        Text(g.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("SidePot 🪙")
        .toolbar {
            Button {
                showCreate = true
            } label: {
                Image(systemName: "plus.circle.fill")
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateGroupSheet(isPresented: $showCreate)
                .environmentObject(store)
        }
        .onAppear {
            store.refreshGroups()
        }
    }
}
