//
//  InMemorySessionStore.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//


import Foundation

final class InMemorySessionStore: SessionStore {
    private var token: String?
    func loadToken() -> String? { token }
    func saveToken(_ token: String) { self.token = token }
    func clear() { token = nil }
}
