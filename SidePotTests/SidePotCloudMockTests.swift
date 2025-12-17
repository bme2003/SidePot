//
//  SidePotCloudMockTests.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//

import XCTest
@testable import SidePot

@MainActor
final class SidePotCloudMockTests: XCTestCase {

    func testSignUpUniqueUsername() async throws {
        let cloud = MockCloudAPI()
        _ = try await cloud.signUp(username: "brody_test_1", password: "password", displayName: "Brody")

        do {
            _ = try await cloud.signUp(username: "brody_test_1", password: "password", displayName: "Brody 2")
            XCTFail("Expected usernameTaken")
        } catch let e as SidePotError {
            XCTAssertEqual(e, .usernameTaken)
        }
    }

    func testSignInAndMe() async throws {
        let cloud = MockCloudAPI()
        let s = try await cloud.signUp(username: "brody_test_2", password: "password", displayName: "Brody")
        let me = try await cloud.me(token: s.token)
        XCTAssertEqual(me.username.lowercased(), "brody_test_2")

        let s2 = try await cloud.signIn(username: "brody_test_2", password: "password")
        let me2 = try await cloud.me(token: s2.token)
        XCTAssertEqual(me2.id, me.id)
    }

    func testGroupInviteAcceptFlow() async throws {
        let cloud = MockCloudAPI()

        let owner = try await cloud.signUp(username: "owner_x", password: "password", displayName: "Owner")
        let group = try await cloud.createGroup(token: owner.token, name: "Group A")

        let invite = try await cloud.createInvite(token: owner.token, groupId: group.id)

        let friend = try await cloud.signUp(username: "friend_x", password: "password", displayName: "Friend")
        let joined = try await cloud.acceptInvite(token: friend.token, code: invite.code)

        XCTAssertEqual(joined.id, group.id)

        let friendGroups = try await cloud.listGroups(token: friend.token)
        XCTAssertTrue(friendGroups.contains(where: { $0.id == group.id }))
    }

    func testBetPledgeAndSettlementCreatesDebtAndLedger() async throws {
        let cloud = MockCloudAPI()

        // Arrange: create group with two members
        let owner = try await cloud.signUp(username: "owner_y", password: "password", displayName: "Owner")
        let group = try await cloud.createGroup(token: owner.token, name: "Group B")
        let invite = try await cloud.createInvite(token: owner.token, groupId: group.id)

        let friend = try await cloud.signUp(username: "friend_y", password: "password", displayName: "Friend")
        _ = try await cloud.acceptInvite(token: friend.token, code: invite.code)

        // Arrange: create bet
        let betId = try await cloud.createBet(
            token: owner.token,
            groupId: group.id,
            title: "Yes/No Bet",
            details: "",
            lockAt: Date().addingTimeInterval(3600),
            resolveAt: Date().addingTimeInterval(7200),
            rule: .creatorDecides,
            outcomes: ["Yes", "No"]
        )

        let bets = try await cloud.listBets(token: owner.token, groupId: group.id)
        guard let bet = bets.first(where: { $0.id == betId }) else {
            return XCTFail("Missing bet")
        }

        guard
            let yesId = bet.outcomes.first(where: { $0.title == "Yes" })?.id,
            let noId  = bet.outcomes.first(where: { $0.title == "No"  })?.id
        else {
            return XCTFail("Missing outcomes")
        }

        // Act: owner bets Yes $10, friend bets No $10, Yes wins
        try await cloud.placeWager(token: owner.token, betId: betId, outcomeId: yesId, dollars: 10)
        try await cloud.placeWager(token: friend.token, betId: betId, outcomeId: noId, dollars: 10)
        try await cloud.resolveBet(token: owner.token, betId: betId, winningOutcomeId: yesId)

        // Assert: debt exists from loser -> winner for $10
        let debts = try await cloud.listDebts(token: owner.token, groupId: group.id)

        guard let openDebt = debts.first(where: { $0.status == .open }) else {
            return XCTFail("Expected an open debt after settlement")
        }

        XCTAssertEqual(openDebt.fromUserId, friend.userId, "Loser should owe the winner")
        XCTAssertEqual(openDebt.toUserId, owner.userId, "Winner should be owed by the loser")
        XCTAssertEqual(openDebt.amount.cents, 10 * 100, "Debt amount should equal the losing wager ($10)")

        // Assert: ledger contains a settlement entry for both users with correct sign
        let ownerLedger = try await cloud.listLedger(token: owner.token, userId: owner.userId)
        let friendLedger = try await cloud.listLedger(token: friend.token, userId: friend.userId)

        let ownerSettlement = ownerLedger.first(where: { $0.title == "Bet settled" })
        let friendSettlement = friendLedger.first(where: { $0.title == "Bet settled" })

        XCTAssertNotNil(ownerSettlement, "Winner should have a 'Bet settled' ledger entry")
        XCTAssertNotNil(friendSettlement, "Loser should have a 'Bet settled' ledger entry")

        if let ownerSettlement {
            XCTAssertEqual(ownerSettlement.delta.cents, 10 * 100, "Winner delta should be +$10")
        }
        if let friendSettlement {
            XCTAssertEqual(friendSettlement.delta.cents, -(10 * 100), "Loser delta should be -$10")
        }
    }
}
