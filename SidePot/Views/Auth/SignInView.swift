//
//  SignInView.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//


import SwiftUI

struct SignInView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var errorText: String?

    var body: some View {
        Form {
            Section("Account") {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
            }

            if let errorText {
                Section {
                    Text(errorText)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Sign In") {
                    Task { await signIn() }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Sign In")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func signIn() async {
        errorText = nil
        do {
            try await store.signIn(username: username, password: password)
            dismiss()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Could not sign in."
        }
    }
}
