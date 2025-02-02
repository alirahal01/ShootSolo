import Foundation
import Combine

@MainActor
class AuthState: ObservableObject {
    static let shared = AuthState()
    
    @Published var isLoggedIn: Bool = false
    @Published var showAuthAlert = false
    
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
        isLoggedIn = false
        showAuthAlert = true
    }
} 