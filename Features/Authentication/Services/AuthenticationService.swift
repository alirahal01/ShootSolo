import Foundation
import Firebase
import GoogleSignIn
import AuthenticationServices
import FirebaseAuth

class AuthenticationService: NSObject, ObservableObject, AuthenticationProtocol {
    @Published var user: UserModel?
    
    func signInWithGoogle(presentingViewController: UIViewController, completion: @escaping (Result<UserModel, Error>) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            completion(.failure(NSError(domain: "com.yourApp.GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing clientID in Firebase configuration"])))
            return
        }

        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Perform Google Sign-In
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(error))
                return
            }

            // Access the GIDGoogleUser from the GIDSignInResult
            guard let user = result?.user else {
                completion(.failure(NSError(domain: "com.yourApp.GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication failed: No user object"])))
                return
            }

            // Retrieve ID Token and Access Token
            guard let idToken = user.idToken?.tokenString else {
                completion(.failure(NSError(domain: "com.yourApp.GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication failed: Missing tokens"])))
                return
            }
            let accessToken = user.accessToken.tokenString
            // Create a credential for Firebase Authentication
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            // Authenticate with Firebase
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let firebaseUser = authResult?.user else {
                    completion(.failure(NSError(domain: "com.yourApp.FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "User sign-in failed"])))
                    return
                }

                // Create UserModel
                let userModel = UserModel(
                    id: firebaseUser.uid,
                    name: firebaseUser.displayName ?? "Unknown User",
                    email: firebaseUser.email ?? "No Email"
                )

                // Update Published User and Call Completion
                DispatchQueue.main.async {
                    self.user = userModel
                    completion(.success(userModel))
                }
            }
        }
    }


    
    func signInWithApple(completion: @escaping (Result<UserModel, Error>) -> Void) {
        // Placeholder for Sign in with Apple logic
        // To be implemented: Handle ASAuthorizationAppleIDProvider flow
        completion(.failure(NSError(domain: "com.yourApp.AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sign in with Apple is not implemented yet."])))
    }
    
    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            self.user = nil
            completion(.success(()))
        } catch let signOutError as NSError {
            completion(.failure(signOutError))
        }
    }

    func isUserLoggedIn() -> Bool {
        return Auth.auth().currentUser != nil
    }

    func signOut() async throws {
        try Auth.auth().signOut()
    }
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "No user logged in", code: 0, userInfo: nil)
        }
        
        try await user.delete()
    }
}
