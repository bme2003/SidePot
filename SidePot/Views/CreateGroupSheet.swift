import SwiftUI

struct CreateGroupSheet: View {
    @EnvironmentObject var store: AppStore
    @Binding var isPresented: Bool
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Group name") {
                    TextField("e.g., Roommates", text: $name)
                }
            }
            .navigationTitle("New group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        store.createGroup(name: name)
                        isPresented = false
                    }
                }
            }
        }
    }
}
