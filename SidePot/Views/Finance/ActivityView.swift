//
//  ActivityView.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//


import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var store: AppStore
    @State private var entries: [LedgerEntry] = []
    @State private var errorText: String?

    var body: some View {
        List {
            if let errorText {
                Text(errorText).foregroundStyle(.red)
            }

            if entries.isEmpty {
                VStack(spacing: 8) {
                    Text("No activity yet.")
                        .foregroundStyle(.secondary)
                    Text("Place a pledge or settle a bet to see it here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .listRowSeparator(.hidden)
            } else {
                ForEach(entries) { e in
                    ActivityRow(entry: e)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Activity")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh") { Task { await load() } }
            }
        }
        .task { await load() }
    }

    private func load() async {
        errorText = nil
        do {
            entries = try await store.listMyActivity()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Could not load activity."
        }
    }
}

private struct ActivityRow: View {
    let entry: LedgerEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                Text(entry.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.delta.dollarsString)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(entry.delta.cents >= 0 ? .green : .red)
        }
        .padding(.vertical, 6)
    }

    private var iconName: String {
        switch entry.title {
        case "Pledge placed": return "hand.tap"
        case "Bet settled": return "checkmark.seal"
        default: return "bolt"
        }
    }
}
