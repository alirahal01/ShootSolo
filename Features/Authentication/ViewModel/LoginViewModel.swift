import Foundation
import Combine
import UIKit

class LoginViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var user: UserModel?
    private var authService: AuthenticationService
    
    init(authService: AuthenticationService = AuthenticationService.shared) {
        self.authService = authService
        checkLoginStatus()
    }
    
    func checkLoginStatus() {
        isLoggedIn = authService.isUserLoggedIn()
    }
    
    func loginWithGoogle(presentingViewController: UIViewController?, completion: @escaping () -> Void) {
        guard let presentingViewController = presentingViewController else {
            print("Error: Presenting view controller is nil.")
            return
        }
        
        authService.signInWithGoogle(presentingViewController: presentingViewController) { [weak self] result in
            switch result {
            case .success(let user):
                DispatchQueue.main.async {
                    self?.user = user
                    self?.isLoggedIn = true
                    completion()
                }
            case .failure(let error):
                print("Google Sign-In failed: \(error.localizedDescription)")
            }
        }
    }
    
    func loginWithApple(completion: @escaping () -> Void) {
        authService.signInWithApple { [weak self] result in
            switch result {
            case .success(let user):
                DispatchQueue.main.async {
                    self?.user = user
                    self?.isLoggedIn = true
                    completion()
                }
            case .failure(let error):
                print("Apple Sign-In failed: \(error.localizedDescription)")
            }
        }
    }
} 
