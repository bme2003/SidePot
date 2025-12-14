import SwiftUI

struct CreateBetSheet: View {
    @EnvironmentObject var store: AppStore
    @Binding var isPresented: Bool
    let group: Group

    @State private var title = ""
    @State private var details = ""
    @State private var clarification = ""
    @State private var lockAt = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
    @State private var resolveAt = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @State private var rule: Bet.Rule = .groupVote
    @State private var outcomesText = "Yes\nNo"

    var body: some View {
        NavigationStack {
            Form {
                Section("Bet") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $details, axis: .vertical)
                    TextField("Clarification (optional)", text: $clarification, axis: .vertical)
                }

                Section("Dates") {
                    DatePicker("Lock date", selection: $lockAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Resolve date", selection: $resolveAt, displayedComponents: [.date, .hourAndMinute])
                }

                Section("House rule") {
                    Picker("Rule", selection: $rule) {
                        ForEach(Bet.Rule.allCases) { r in
                            Text(r.displayName).tag(r)
                        }
                    }
                }

                Section("Outcomes (one per line)") {
                    TextEditor(text: $outcomesText)
                        .frame(minHeight: 90)
                        .font(.body)
                }
            }
            .navigationTitle("New Bet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let outs = outcomesText.split(separator: "\n").map { String($0) }
                        store.createBet(
                            groupId: group.id,
                            title: title.isEmpty ? "Untitled Bet" : title,
                            details: details.isEmpty ? "No description." : details,
                            clarification: clarification.isEmpty ? nil : clarification,
                            lockAt: lockAt,
                            resolveAt: resolveAt,
                            rule: rule,
                            outcomes: outs
                        )
                        isPresented = false
                    }
                }
            }
        }
    }
}
