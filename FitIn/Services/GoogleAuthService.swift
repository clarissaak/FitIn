//
//  GoogleAuthService.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/21/26.
//
import Foundation
import UIKit
import GoogleSignIn

// Wraps GIDSignIn to provide a simple async interface for sign-in,
// session restoration, and token access. Requests Sheets + Drive scopes
// alongside the default OpenID/email/profile scopes at sign-in time.
//
// If a token refresh ever fails (revoked access, expired refresh token,
// etc.), this signs the user out and posts .authSessionExpired so the
// app can route back to sign-in rather than silently failing deeper
// network calls.
@MainActor
final class GoogleAuthService {

    static let shared = GoogleAuthService()

    private init() {}

    // Scopes needed beyond the default openid/email/profile that GIDSignIn
    // requests automatically.
    private let additionalScopes = [
        "https://www.googleapis.com/auth/spreadsheets",
        "https://www.googleapis.com/auth/drive.file"
    ]

    struct AuthenticatedUser {
        let name: String?
        let email: String?
        let sub: String
    }

    // MARK: - Sign in

    // Presents the Google Sign-In flow from the given view controller.
    func signIn(presenting: UIViewController) async throws -> AuthenticatedUser {
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presenting,
            hint: nil,
            additionalScopes: additionalScopes
        )
        return AuthenticatedUser(
            name: result.user.profile?.name,
            email: result.user.profile?.email,
            sub: result.user.userID ?? ""
        )
    }

    // MARK: - Restore previous session

    // Attempts to restore a previously signed-in session (e.g. on app launch).
    // Returns nil if there was no previous session or it could not be restored.
    func restorePreviousSignIn() async -> AuthenticatedUser? {
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else { return nil }
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            return AuthenticatedUser(
                name: user.profile?.name,
                email: user.profile?.email,
                sub: user.userID ?? ""
            )
        } catch {
            return nil
        }
    }

    // MARK: - Sign out

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: - Access token (auto-refreshing)

    // Returns a valid access token, refreshing it first if needed. If the
    // refresh itself fails (e.g. the user revoked access, or the refresh
    // token expired), this signs the user out and posts
    // .authSessionExpired before rethrowing, so the app can prompt re-auth
    // instead of every caller having to handle this individually.
    func validAccessToken() async throws -> String {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw AuthError.noCurrentUser
        }
        do {
            let refreshedUser = try await currentUser.refreshTokensIfNeeded()
            return refreshedUser.accessToken.tokenString
        } catch {
            signOut()
            NotificationCenter.default.post(name: .authSessionExpired, object: nil)
            throw AuthError.sessionExpired
        }
    }

    // Returns the currently signed-in user, if any, without triggering
    // a network refresh.
    var currentUser: AuthenticatedUser? {
        guard let user = GIDSignIn.sharedInstance.currentUser else { return nil }
        return AuthenticatedUser(
            name: user.profile?.name,
            email: user.profile?.email,
            sub: user.userID ?? ""
        )
    }

    enum AuthError: Error {
        case noCurrentUser
        case sessionExpired
    }
}

extension Notification.Name {
    // Posted when a token refresh fails and the user has been signed out
    // as a result. AuthViewModel listens for this to route back to
    // sign-in with an explanatory message.
    static let authSessionExpired = Notification.Name("authSessionExpired")
}
