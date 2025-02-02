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
    }
    
    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }
    
    private func setupFirebaseAuthStateListener() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            guard let self = self else { return }
            
            if let user = user {
                // Check if user token is still valid
                Task {
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
                            print("Other Firebase error: \(error)")
                        }
                    }
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
            self.isLoggedIn = false
            self.showAuthAlert = true
            print("Auth State: Alert should show - showAuthAlert: \(self.showAuthAlert)")
        }
    }
} 
