//
//  AuthViewModel.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/21/26.
//
import Foundation
import SwiftUI
import Combine
import UIKit

// Drives auth state for the app root: whether a user is signed in,
// who they are, and any in-flight error to surface in the UI.
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
}
