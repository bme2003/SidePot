//
//  GroupMembersView.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//

import SwiftUI

struct GroupMembersView: View {
    let groupId: UUID

    @EnvironmentObject var store: AppStore
    @StateObject private var api = MockAPI.shared

    @State private var group: Group?
    @State private var showAddMember = false
    @State private var showContactPicker = false

    var body: some View {
        List {
            if let group {
                Section {
                    ForEach(group.memberIds, id: \.self) { uid in
                        let name = api.displayName(uid)
                        let uname = api.user(for: uid)?.username ?? "unknown"
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(name).font(.headline)
                                Text("@\(uname)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if uid == group.ownerId {
                                Pill(text: "Owner", systemImage: "checkmark.seal")
                            }
                        }
                        .padding(.vertical, 6)
                        .swipeActions {
                            if store.me.id == group.ownerId && uid != group.ownerId {
                                Button(role: .destructive) {
                                    api.removeMember(groupId: groupId, userId: uid)
                                    reload()
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Members")
                }

                Section {
                    Button {
                        showAddMember = true
                    } label: {
                        Label("Add by username", systemImage: "person.badge.plus")
                    }

                    Button {
                        showContactPicker = true
                    } label: {
                        Label("Invite from contacts", systemImage: "person.crop.circle.badge.plus")
                    }
                } header: {
                    Text("Add people")
                }

                Section {
                    NavigationLink {
                        PendingInvitesView(groupId: groupId)
                    } label: {
                        Label("Pending invites", systemImage: "clock")
                    }
                }
            }
        }
        .navigationTitle("People")
        .sheet(isPresented: $showAddMember) {
            AddMemberSheet(isPresented: $showAddMember, groupId: groupId)
                .environmentObject(store)
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPicker { selected in
                api.createInvite(groupId: groupId,
                                 contactName: selected.name,
                                 contactIdentifier: selected.identifier)
                reload()
            }
        }
        .onAppear { reload() }
    }

    private func reload() {
        group = api.getGroup(groupId)
    }
}
