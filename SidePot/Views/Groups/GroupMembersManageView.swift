//
//  GroupMembersManageView.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//


import SwiftUI

struct GroupMembersManageView: View {
    let groupId: UUID

    @EnvironmentObject var store: AppStore
    @State private var errorText: String?

    private var group: Group? { store.groups.first(where: { $0.id == groupId }) }
    private var meId: UUID? { store.me?.id }
    private var isOwner: Bool { group?.ownerId == meId }

    var body: some View {
        List {
            if !isOwner {
                Text("Only the group owner can remove members.")
                    .foregroundStyle(.secondary)
            } else if let group {
                Section("Members") {
                    ForEach(group.memberIds, id: \.self) { memberId in
                        HStack {
                            Text(memberId == group.ownerId ? "Owner" : "Member")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.thinMaterial)
                                .clipShape(Capsule())

                            Text(memberId.uuidString.prefix(10))
                                .font(.subheadline)

                            Spacer()

                            if memberId != group.ownerId {
                                Button(role: .destructive) {
                                    Task { await remove(memberId) }
                                } label: {
                                    Label("Remove", systemImage: "person.fill.xmark")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            if let errorText {
                Section { Text(errorText).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Members")
        .task { await store.refreshGroups() }
    }

    private func remove(_ memberId: UUID) async {
        errorText = nil
        do {
            try await store.removeMember(groupId: groupId, memberId: memberId)
            await store.refreshGroups()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Could not remove member."
        }
    }
}
