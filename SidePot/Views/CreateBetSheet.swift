import SwiftUI

struct CreateBetSheet: View {
    @EnvironmentObject var store: AppStore
    @Binding var isPresented: Bool
    let groupId: UUID

    @StateObject private var api = MockAPI.shared

    @State private var title = ""
    @State private var details = ""
    @State private var lockAt = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
    @State private var resolveAt = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @State private var rule: Bet.Rule = .groupVote
    @State private var outcomesText = "Yes\nNo"

    var body: some View {
        NavigationStack {
            Form {
                if store.isLockedOut() {
                    Section {
                        Text("You have unresolved debts. You cannot create new bets until they are resolved.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Bet") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $details, axis: .vertical)
                }

                Section("Dates") {
                    DatePicker("Lock", selection: $lockAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Resolve", selection: $resolveAt, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Rule") {
                    Picker("Rule", selection: $rule) {
                        ForEach(Bet.Rule.allCases) { r in
                            Text(r.displayName).tag(r)
                        }
                    }
                }

                Section("Outcomes (one per line)") {
                    TextEditor(text: $outcomesText)
                        .frame(minHeight: 90)
                }
            }
            .navigationTitle("New bet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let outs = outcomesText.split(separator: "\n").map { String($0) }
                        api.createBet(
                            groupId: groupId,
                            title: title,
                            details: details,
                            lockAt: lockAt,
                            resolveAt: resolveAt,
                            rule: rule,
                            outcomes: outs
                        )
                        isPresented = false
                    }
                    .disabled(store.isLockedOut())
                }
            }
        }
    }
}
