//
//  AuthGateView.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//


import SwiftUI

struct AuthGateView: View {
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("SidePot")
                    .font(.largeTitle)
                    .bold()

                Text("Sign in to continue.")
                    .foregroundStyle(.secondary)

                NavigationLink("Sign In") {
                    SignInView()
                }
                .buttonStyle(.borderedProminent)

                Button("Create an account") {
                    showSignUp = true
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showSignUp) {
                NavigationStack { SignUpView() }
            }
        }
    }
}
