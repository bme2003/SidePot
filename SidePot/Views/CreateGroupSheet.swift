//
//  CreateGroupSheet.swift
//  SidePot
//
//  Created by Brody England on 12/14/25.
//

import SwiftUI

struct CreateGroupSheet: View {
    @EnvironmentObject var store: AppStore
    @Binding var isPresented: Bool
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Name") {
                    TextField("e.g., Roommates", text: $name)
                }
            }
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.createGroup(name: finalName.isEmpty ? "Untitled Group" : finalName)
                        isPresented = false
                    }
                }
            }
        }
    }
}
