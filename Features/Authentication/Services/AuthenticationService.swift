import Foundation
import Firebase
import GoogleSignIn
import AuthenticationServices
import FirebaseAuth
import CryptoKit

class AuthenticationService: NSObject, ObservableObject, AuthenticationProtocol, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AuthenticationService()
    
    @Published var user: UserModel?
    private var currentNonce: String?
    private var signInCompletion: ((Result<UserModel, Error>) -> Void)?
    @Published var isAuthenticated = false
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    private override init() {
        super.init()
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] (auth, firebaseUser) in
            guard let self = self else { return }
            
            if let firebaseUser = firebaseUser {
                let user = UserModel(
                    id: firebaseUser.uid,
                    name: firebaseUser.displayName ?? "Unknown User",
                    email: firebaseUser.email ?? "No Email"
                )
                DispatchQueue.main.async {
                    self.user = user
                    self.isAuthenticated = true
                    // Trigger credits sync when user signs in
                    Task {
                        try? await CreditsManager.shared.fetchCreditsFromFirestore()
                    }
                }
            } else {
                // User is not authenticated, handle sign out
                Task { @MainActor in
                    await self.handleUnauthenticated()
                }
            }
        }
    }
    
    @MainActor
    private func handleUnauthenticated() async {
        // Clear user data
        self.user = nil
        self.isAuthenticated = false
        
        // Attempt to sign out properly
        do {
            try await self.signOut()
        } catch {
            print("Error signing out: \(error)")
        }
        
        // Post notification for other parts of the app
        NotificationCenter.default.post(
            name: .userDidBecomeUnauthenticated,
            object: nil
        )
    }
    
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
        self.signInCompletion = completion
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            signInCompletion?(.failure(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"])))
            return
        }
        
        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idTokenString,
            rawNonce: nonce
        )
        
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            if let error = error {
                self?.signInCompletion?(.failure(error))
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                self?.signInCompletion?(.failure(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create user"])))
                return
            }
            
            // Get user's name from the Apple ID credential
            var displayName = firebaseUser.displayName ?? "Unknown User"
            if let fullName = appleIDCredential.fullName {
                displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                // Update Firebase display name if we got it from Apple
                if !displayName.isEmpty {
                    let changeRequest = firebaseUser.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    changeRequest.commitChanges(completion: nil)
                }
            }
            
            let userModel = UserModel(
                id: firebaseUser.uid,
                name: displayName,
                email: firebaseUser.email ?? "No Email"
            )
            
            DispatchQueue.main.async {
                self?.user = userModel
                self?.signInCompletion?(.success(userModel))
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        signInCompletion?(.failure(error))
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let window = UIApplication.shared.windows.first else {
            fatalError("No window found")
        }
        return window
    }
    
    // MARK: - Helper Methods
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
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

    var currentUser: UserModel? {
        guard let firebaseUser = Auth.auth().currentUser else { return nil }
        return UserModel(
            id: firebaseUser.uid,
            name: firebaseUser.displayName ?? "Unknown User",
            email: firebaseUser.email ?? "No Email"
        )
    }
}

// Add notification name
extension Notification.Name {
    static let userDidBecomeUnauthenticated = Notification.Name("userDidBecomeUnauthenticated")
}
