import SwiftUI

@main
struct SidePotApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task { await store.bootstrap() }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { GroupsView() }
                .tabItem { Label("Groups", systemImage: "person.3.fill") }

            NavigationStack { FriendsView() }
                .tabItem { Label("Friends", systemImage: "person.crop.circle.badge.plus") }

            NavigationStack { LedgerView() }
                .tabItem { Label("Ledger", systemImage: "list.bullet.rectangle") }

            NavigationStack { UserStatsView() }
                .tabItem { Label("Me", systemImage: "person.circle") }
        }
    }
}
