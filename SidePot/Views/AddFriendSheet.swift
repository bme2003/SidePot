//
//  AddFriendSheet.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//

import SwiftUI

struct AddFriendSheet: View {
    @EnvironmentObject var store: AppStore
    @Binding var isPresented: Bool

    @State private var username = ""
    @State private var displayName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Username") {
                    TextField("e.g., alex", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Display name") {
                    TextField("e.g., Alex", text: $displayName)
                }
            }
            .navigationTitle("Add friend")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
                        let d = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !u.isEmpty else { return }
                        store.addFriend(username: u, displayName: d.isEmpty ? u : d)
                        isPresented = false
                    }
                }
            }
        }
    }
}
