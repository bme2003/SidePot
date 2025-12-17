//
//  CreateGroupSheet.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//


import SwiftUI

struct CreateGroupSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Group") {
                    TextField("Group name", text: $name)
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
                Section {
                    Button("Create") {
                        Task { await create() }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func create() async {
        errorText = nil
        do {
            try await store.createGroup(name: name)
            dismiss()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Could not create group."
        }
    }
}
