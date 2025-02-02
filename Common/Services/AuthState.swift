import Foundation
import Combine
import FirebaseAuth

@MainActor
class AuthState: ObservableObject {
    static let shared = AuthState()
    
    @Published var isLoggedIn: Bool = false
    @Published var showAuthAlert = false
    private let authService = AuthenticationService.shared
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    
    private init() {
        setupAuthenticationListener()
        setupFirebaseAuthStateListener()
        // Initialize isLoggedIn based on current auth state
        isLoggedIn = Auth.auth().currentUser != nil
    }
    
    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }
    
    private func setupFirebaseAuthStateListener() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let user = user {
                    // User is logged in
                    self.isLoggedIn = true
                    
                    // Check if user token is still valid
                    do {
                        _ = try await user.getIDToken(forcingRefresh: true)
                    } catch let error as NSError {
                        // Check for specific Firebase error codes
                        switch error.code {
                        case AuthErrorCode.userNotFound.rawValue,
                             AuthErrorCode.userDisabled.rawValue:
                            print("Firebase: User disabled or deleted")
                            await self.handleUserDisabled()
                        default:
                            // Don't show the auth alert for other token refresh errors
                            print("Other Firebase error: \(error)")
                        }
                    }
                } else {
                    // User is logged out
                    self.isLoggedIn = false
                }
            }
        }
    }
    
    private func handleUserDisabled() async {
        print("Auth State: Handling disabled user")
        do {
            try await authService.signOut()
            await MainActor.run {
                self.isLoggedIn = false
                self.showAuthAlert = true
            }
        } catch {
            print("Error signing out disabled user: \(error)")
        }
    }
    
    private func setupAuthenticationListener() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnauthenticated),
            name: .userDidBecomeUnauthenticated,
            object: nil
        )
    }
    
    @objc private func handleUnauthenticated() {
        print("Auth State: Handling unauthenticated state")
        Task { @MainActor in
            // Only show auth alert if we were previously logged in
            if isLoggedIn {
                self.isLoggedIn = false
                self.showAuthAlert = true
                print("Auth State: Alert should show - showAuthAlert: \(self.showAuthAlert)")
            }
        }
    }
} 
