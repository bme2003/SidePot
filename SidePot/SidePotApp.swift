//
//  SidePotApp.swift
//  SidePot
//
//  Created by Brody England on 12/14/25.
//

import SwiftUI

@main
struct SidePotApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task {
                    await store.bootstrap()
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabView {
            NavigationStack {
                GroupsView()
            }
            .tabItem { Label("Groups", systemImage: "person.3.fill") }

            NavigationStack {
                LedgerView()
            }
            .tabItem { Label("Ledger", systemImage: "list.bullet.rectangle") }

            NavigationStack {
                UserStatsView()
            }
            .tabItem { Label("Me", systemImage: "person.crop.circle") }
        }
    }
}

