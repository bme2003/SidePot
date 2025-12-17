//
//  Services.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//

import Foundation

// MARK: - Session

struct Session: Codable, Hashable {
    let token: String
    let userId: UUID
}

// MARK: - Errors

enum SidePotError: LocalizedError, Equatable {
    case notSignedIn
    case usernameTaken
    case invalidCredentials
    case forbidden
    case notFound
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Not signed in."
        case .usernameTaken: return "Username already taken."
        case .invalidCredentials: return "Invalid username or password."
        case .forbidden: return "You don’t have permission."
        case .notFound: return "Not found."
        case .validation(let msg): return msg
        }
    }
}

// MARK: - Protocols

protocol SessionStore {
    func loadToken() -> String?
    func saveToken(_ token: String)
    func clear()
}

protocol AuthService {
    func signUp(username: String, password: String, displayName: String) async throws -> Session
    func signIn(username: String, password: String) async throws -> Session
    func me(token: String) async throws -> UserProfile
}

protocol GroupsService {
    func listGroups(token: String) async throws -> [Group]
    func createGroup(token: String, name: String) async throws -> Group
    func createInvite(token: String, groupId: UUID) async throws -> Invite
    func acceptInvite(token: String, code: String) async throws -> Group
}

protocol BetsService {
    func listBets(token: String, groupId: UUID) async throws -> [Bet]
    func createBet(
        token: String,
        groupId: UUID,
        title: String,
        details: String,
        lockAt: Date,
        resolveAt: Date,
        rule: Bet.Rule,
        outcomes: [String]
    ) async throws -> UUID

    func placeWager(token: String, betId: UUID, outcomeId: UUID, dollars: Int) async throws
    func resolveBet(token: String, betId: UUID, winningOutcomeId: UUID) async throws
    func listDebts(token: String, groupId: UUID) async throws -> [Debt]
    func resolveDebt(token: String, debtId: UUID) async throws
    func listLedger(token: String, userId: UUID) async throws -> [LedgerEntry]
}
