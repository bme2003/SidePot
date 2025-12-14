import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var me: UserProfile = UserProfile(id: UUID(), displayName: "Me")
    @Published var groups: [Group] = []
    @Published var selectedGroup: Group?
    @Published var bets: [Bet] = []

    private let api = MockAPI.shared

    func bootstrap() async {
        me = api.getMe()
        refreshGroups()
        if let first = groups.first {
            selectedGroup = first
            refreshBets(groupId: first.id)
        }
    }

    func refreshGroups() {
        groups = api.listGroups()
    }

    func refreshBets(groupId: UUID) {
        bets = api.listBets(groupId: groupId)
    }

    // Actions
    func createGroup(name: String) {
        api.createGroup(name: name)
        refreshGroups()
    }

    func createBet(groupId: UUID,
                   title: String,
                   details: String,
                   clarification: String?,
                   lockAt: Date,
                   resolveAt: Date,
                   rule: Bet.Rule,
                   outcomes: [String]) {
        api.createBet(groupId: groupId,
                      title: title,
                      details: details,
                      clarification: clarification,
                      lockAt: lockAt,
                      resolveAt: resolveAt,
                      rule: rule,
                      outcomes: outcomes)
        refreshBets(groupId: groupId)
    }
}
