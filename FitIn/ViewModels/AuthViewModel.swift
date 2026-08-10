//
//  AuthViewModel.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/21/26.
//
import Foundation
import Combine
import UIKit
import SwiftUI

// Drives auth state for the app root: whether a user is signed in,
// who they are, and any in-flight error to surface in the UI. Also
// listens for .authSessionExpired (posted when a token refresh fails)
// so a mid-use session expiry routes back to sign-in with an
// explanatory message, instead of leaving deeper screens stuck on
// failed network calls.
@MainActor
final class AuthViewModel: ObservableObject {

    enum State {
        case checkingSession
        case signedOut
        case signedIn(GoogleAuthService.AuthenticatedUser)
    }

    @Published private(set) var state: State = .checkingSession
    @Published var errorMessage: String?

    private let authService = GoogleAuthService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: .authSessionExpired)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleSessionExpired()
            }
            .store(in: &cancellables)
    }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    var currentUser: GoogleAuthService.AuthenticatedUser? {
        if case .signedIn(let user) = state { return user }
        return nil
    }

    // Call once on app launch to silently restore a previous session, if any.
    func restoreSessionIfAvailable() async {
        state = .checkingSession
        if let user = await authService.restorePreviousSignIn() {
            state = .signedIn(user)
        } else {
            state = .signedOut
        }
    }

    // Call from the sign-in button's action.
    func signIn(presenting: UIViewController) async {
        errorMessage = nil
        do {
            let user = try await authService.signIn(presenting: presenting)
            state = .signedIn(user)
        } catch {
            errorMessage = "Sign-in failed. Please try again."
            state = .signedOut
        }
    }

    func signOut() {
        authService.signOut()
        state = .signedOut
    }

    private func handleSessionExpired() {
        state = .signedOut
        errorMessage = "Your session expired. Please sign in again."
    }
}
