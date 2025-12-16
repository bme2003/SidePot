//
//  PendingInvitesView.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//

import SwiftUI

struct PendingInvitesView: View {
    let groupId: UUID
    @StateObject private var api = MockAPI.shared

    var body: some View {
        let invites = api.listInvites(groupId: groupId)

        List {
            if invites.isEmpty {
                Text("No pending invites.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(invites) { inv in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(inv.contactName).font(.headline)
                        Text("Created \(inv.createdAt, style: .date)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .swipeActions {
                        Button(role: .destructive) {
                            api.deleteInvite(inviteId: inv.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Pending invites")
    }
}
