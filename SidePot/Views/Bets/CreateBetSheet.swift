//
//  CreateBetSheet.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//

import SwiftUI

struct CreateBetSheet: View {
    let groupId: UUID
    let onCreated: () -> Void

    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var details = ""
    @State private var lockAt = Date().addingTimeInterval(60 * 10)
    @State private var resolveAt = Date().addingTimeInterval(60 * 60 * 24)

    enum OutcomeMode: String, CaseIterable, Identifiable {
        case yesNo = "Yes / No"
        case custom = "Custom"
        var id: String { rawValue }
    }

    @State private var outcomeMode: OutcomeMode = .yesNo
    @State private var customOutcomes: [String] = ["", ""]

    @State private var errorText: String?

    private var isLockedOut: Bool { store.isLockedOut(in: groupId) }

    private var canCreate: Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        if resolveAt <= lockAt { return false }
        if isLockedOut { return false }

        let outs = computedOutcomes()
        return outs.count >= 2
    }

    var body: some View {
        NavigationStack {
            Form {
                if isLockedOut {
                    Section {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 16, weight: .semibold))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Action blocked")
                                    .font(.headline)
                                Text("Resolve your debt before creating new bets.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Bet") {
                    TextField("Title", text: $title)
                    TextField("Details (optional)", text: $details, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Timing") {
                    DatePicker("Lock betting", selection: $lockAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Resolve by", selection: $resolveAt, displayedComponents: [.date, .hourAndMinute])

                    if resolveAt <= lockAt {
                        Text("Resolve time must be after lock time.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Outcomes") {
                    Picker("Type", selection: $outcomeMode) {
                        ForEach(OutcomeMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if outcomeMode == .yesNo {
                        HStack {
                            Label("Yes", systemImage: "checkmark.circle")
                            Spacer()
                            Label("No", systemImage: "xmark.circle")
                        }
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(customOutcomes.indices, id: \.self) { i in
                                HStack {
                                    TextField("Outcome \(i + 1)", text: Binding(
                                        get: { customOutcomes[i] },
                                        set: { customOutcomes[i] = $0 }
                                    ))
                                    .textInputAutocapitalization(.sentences)

                                    if customOutcomes.count > 2 {
                                        Button(role: .destructive) {
                                            customOutcomes.remove(at: i)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }

                            Button {
                                customOutcomes.append("")
                            } label: {
                                Label("Add outcome", systemImage: "plus.circle.fill")
                            }
                        }
                        .padding(.vertical, 4)

                        let preview = computedOutcomes()
                        if preview.count < 2 {
                            Text("Add at least 2 non-empty outcomes.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }

                Section {
                    Button {
                        Task { await create() }
                    } label: {
                        Text(isLockedOut ? "Locked" : "Create Bet")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(!canCreate)
                }
            }
            .navigationTitle("New Bet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func computedOutcomes() -> [String] {
        if outcomeMode == .yesNo {
            return ["Yes", "No"]
        }

        // Trim, remove empties, remove duplicates (case-insensitive), preserve order
        let trimmed = customOutcomes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        var result: [String] = []
        for o in trimmed {
            let key = o.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                result.append(o)
            }
        }
        return result
    }

    private func create() async {
        errorText = nil
        do {
            let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let d = details.trimmingCharacters(in: .whitespacesAndNewlines)
            let outcomes = computedOutcomes()

            _ = try await store.createBet(
                groupId: groupId,
                title: t,
                details: d,
                lockAt: lockAt,
                resolveAt: resolveAt,
                rule: Bet.Rule.creatorDecides,
                outcomes: outcomes
            )

            onCreated()
            dismiss()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Could not create bet."
        }
    }
}
