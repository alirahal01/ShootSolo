import Foundation
import Combine


@MainActor
class AuthState: ObservableObject {
    static let shared = AuthState()
    
    @Published var isLoggedIn: Bool = false
    @Published var showAuthAlert = false
    private let authService = AuthenticationService.shared
    
    private init() {
        setupAuthenticationListener()
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
        print("Auth State: Handling unauthenticated state") // Debug log
        Task { @MainActor in
            try? await authService.signOut()
            self.isLoggedIn = false
            self.showAuthAlert = true
            print("Auth State: Alert should show - showAuthAlert: \(self.showAuthAlert)") // Debug log
        }
    }
} 
