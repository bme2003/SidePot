import SwiftUI

struct AddMemberSheet: View {
    @EnvironmentObject var store: AppStore
    @Binding var isPresented: Bool
    let groupId: UUID

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
                Section {
                    Text("In mock mode this creates a local user. In production this would look up an existing account.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add member")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { isPresented = false }) {
                        Text("Cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: addMember) {
                        Text("Add")
                    }
                    .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func addMember() {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let d = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return }
        store.addMember(groupId: groupId, username: u, displayName: d.isEmpty ? u : d)
        isPresented = false
    }
}
