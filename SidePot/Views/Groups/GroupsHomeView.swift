//
//  GroupsHomeView.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//


import SwiftUI

struct GroupsHomeView: View {
    @EnvironmentObject var store: AppStore

    @State private var showCreateGroup = false
    @State private var showJoin = false
    @State private var joinCode = ""
    @State private var joinError: String?

    var body: some View {
        List {
            if store.groups.isEmpty {
                VStack(spacing: 8) {
                    Text("No groups yet.")
                        .foregroundStyle(.secondary)
                    Text("Create one and start a bet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .listRowSeparator(.hidden)
            } else {
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
        .listStyle(.insetGrouped)
        .navigationTitle("Groups")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("Sign Out", role: .destructive) { store.signOut() }
                } label: {
                    Image(systemName: "person.circle")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Create Group") { showCreateGroup = true }
                    Button("Join via Code") { showJoin = true }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $showJoin) {
            NavigationStack {
                Form {
                    Section("Invite code") {
                        TextField("Code", text: $joinCode)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    if let joinError {
                        Section { Text(joinError).foregroundStyle(.red) }
                    }
                    Section {
                        Button("Join") { Task { await join() } }
                    }
                }
                .navigationTitle("Join Group")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showJoin = false }
                    }
                }
            }
        }
    }

    private func join() async {
        joinError = nil
        do {
            try await store.acceptInvite(code: joinCode)
            showJoin = false
            joinCode = ""
        } catch {
            joinError = (error as? LocalizedError)?.errorDescription ?? "Could not join."
        }
    }
}
