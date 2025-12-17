//
//  Invite.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//


import Foundation

struct Invite: Codable, Identifiable, Hashable {
    let id: UUID
    let groupId: UUID
    let code: String
    let createdByUserId: UUID
    let createdAt: Date
    let expiresAt: Date
    var usedByUserId: UUID?
}
