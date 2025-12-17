import SwiftUI

@main
struct SidePotApp: App {

    @StateObject private var store: AppStore

    init() {
        let cloud = MockCloudAPI()
        let sessionStore = KeychainSessionStore()
        _store = StateObject(
            wrappedValue: AppStore(
                auth: cloud,
                groups: cloud,
                bets: cloud,
                sessionStore: sessionStore
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task { await store.restoreSession() }
        }
    }
}

private struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        if store.isSignedIn {
            MainTabView()
        } else {
            AuthGateView()
        }
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { GroupsHomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack { ActivityView() }
                .tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }

            NavigationStack { BalanceView() }
                .tabItem { Label("Balance", systemImage: "creditcard.fill") }
        }
    }
}
