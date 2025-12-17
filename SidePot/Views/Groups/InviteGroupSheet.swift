//
//  InviteGroupSheet.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//


import SwiftUI

struct InviteGroupSheet: View {
    let groupId: UUID

    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var code: String?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                if let code {
                    Text("Invite Code")
                        .font(.headline)
                    Text(code)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .textSelection(.enabled)

                    ShareLink(item: code) {
                        Label("Share code", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                } else if let errorText {
                    Text(errorText).foregroundStyle(.red)
                } else {
                    ProgressView("Creating invite…")
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Invite")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            let inv = try await store.createInvite(groupId: groupId)
            code = inv.code
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Could not create invite."
        }
    }
}
