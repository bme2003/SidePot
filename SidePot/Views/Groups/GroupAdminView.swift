//
//  GroupAdminView.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//


import SwiftUI

struct GroupAdminView: View {
    let groupId: UUID

    @EnvironmentObject var store: AppStore
    @State private var debts: [Debt] = []
    @State private var errorText: String?

    private var group: Group? { store.groups.first(where: { $0.id == groupId }) }
    private var meId: UUID? { store.me?.id }
    private var isOwner: Bool { group?.ownerId == meId }

    // members who owe money (open debts)
    private var openDebts: [Debt] { debts.filter { $0.status == .open } }

    private var openDebtsByDebtor: [UUID: [Debt]] {
        Dictionary(grouping: openDebts, by: { $0.fromUserId })
    }

    var body: some View {
        List {
            if !isOwner {
                Text("Only the group owner can manage debts.")
                    .foregroundStyle(.secondary)
            } else {
                Section("Unresolved debts") {
                    if openDebts.isEmpty {
                        Text("No open debts.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(openDebtsByDebtor.keys.sorted(by: { $0.uuidString < $1.uuidString }), id: \.self) { debtorId in
                            NavigationLink {
                                DebtorDetailView(
                                    groupId: groupId,
                                    debtorId: debtorId,
                                    debts: openDebtsByDebtor[debtorId] ?? []
                                )
                                .environmentObject(store)
                            } label: {
                                let count = openDebtsByDebtor[debtorId]?.count ?? 0
                                let total = (openDebtsByDebtor[debtorId] ?? []).reduce(0) { $0 + $1.amount.cents }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Member \(debtorId.uuidString.prefix(6))")
                                        .font(.headline)
                                    Text("\(count) debt(s) • $\(Double(total)/100.0, specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    NavigationLink {
                        GroupMembersManageView(groupId: groupId)
                            .environmentObject(store)
                    } label: {
                        Text("Manage members")
                    }
                }
            }

            if let errorText {
                Section { Text(errorText).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Group Admin")
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
            await store.refreshGroups()
            debts = try await store.listDebts(groupId: groupId)
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Could not load debts."
        }
    }
}

private struct DebtorDetailView: View {
    let groupId: UUID
    let debtorId: UUID
    let debts: [Debt]

    @EnvironmentObject var store: AppStore
    @State private var working = false
    @State private var errorText: String?

    var body: some View {
        List {
            Section {
                let total = debts.reduce(0) { $0 + $1.amount.cents }
                Text("Open total: $\(Double(total)/100.0, specifier: "%.2f")")
                    .font(.headline)
            }

            Section("Debts") {
                ForEach(debts) { d in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Amount \(d.amount.dollarsString)")
                                .font(.headline)
                            Text("Created \(d.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Resolve") {
                            Task { await resolve(d.id) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(working)
                    }
                }
            }

            if let errorText {
                Section { Text(errorText).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Resolve Debts")
    }

    private func resolve(_ debtId: UUID) async {
        working = true
        errorText = nil
        do {
            try await store.resolveDebt(debtId: debtId)
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Could not resolve."
        }
        working = false
    }
}
