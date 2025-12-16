//
//  FriendsView.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                ForEach(store.friends) { f in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(f.displayName).font(.headline)
                        Text("@\(f.username)").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                .onDelete { idx in
                    let api = MockAPI.shared
                    for i in idx { api.removeFriend(friendId: store.friends[i].id) }
                    store.refreshAll()
                }
            } header: {
                Text("Friends")
            }

            Section {
                Text("Add friends by username. You can then add them to groups.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Friends")
        .toolbar {
            Button { showAdd = true } label: { Image(systemName: "plus.circle.fill") }
        }
        .sheet(isPresented: $showAdd) {
            AddFriendSheet(isPresented: $showAdd)
                .environmentObject(store)
        }
        .onAppear { store.refreshAll() }
    }
}
