import Foundation
import StoreKit
import FirebaseFirestore
import FirebaseAuth

@MainActor
class CreditsManager: ObservableObject, CreditsManagerProtocol {
    static let shared = CreditsManager(authService: AuthenticationService.shared)
    
    @Published private(set) var products: [ProductModel] = []
    @Published var creditsBalance: Int = 0
    @Published private(set) var purchaseInProgress = false
    @Published var error: String?
    @Published private(set) var isLoadingProducts = false
    
    private let userDefaults = UserDefaults.standard
    private let creditsKey = "user_credits_balance"
    private let freeCreditsAmount = 5
    private let initialCreditsAmount = 20
    
    private let db = Firestore.firestore()
    private var authService: AuthenticationService
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    var userId: String? {
        authService.user?.id
    }
    
    private init(authService: AuthenticationService) {
        self.authService = authService
        
        // Setup auth state listener
        setupAuthStateListener()
        
        // Setup unauthenticated notification observer
        setupUnauthenticatedObserver()
        
        // Start observing transactions
        Task {
            await observeTransactions()
        }
        
        // Load products
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUnauthenticatedObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnauthenticated),
            name: .userDidBecomeUnauthenticated,
            object: nil
        )
    }
    
    @objc private func handleUnauthenticated() {
        // Reset local state
        creditsBalance = 0
        userDefaults.removeObject(forKey: creditsKey)
        error = "Session expired. Please sign in again."
        
        // Optionally notify UI or handle any cleanup
        objectWillChange.send()
    }
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            guard let self = self else { return }
            
            if user != nil {
                // User is signed in, fetch credits
                Task {
                    try? await self.fetchCreditsFromFirestore()
                }
            } else {
                // User is signed out, handle locally
                Task { @MainActor in
                    self.handleUnauthenticated()
                }
            }
        }
    }
    
    private func observeTransactions() async {
        // Handle transactions that occurred while the app was not running
        for await verification in Transaction.currentEntitlements {
            if case .verified(let transaction) = verification {
                // Handle transaction
                if let iapProduct = IAPProduct(rawValue: transaction.productID) {
                    await addCredits(iapProduct.credits)
                }
                await transaction.finish()
            }
        }
        
        // Handle new transactions
        for await verification in Transaction.updates {
            if case .verified(let transaction) = verification {
                // Handle transaction
                if let iapProduct = IAPProduct(rawValue: transaction.productID) {
                    await addCredits(iapProduct.credits)
                }
                await transaction.finish()
            }
        }
    }
    
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        
        do {
            let productIdentifiers = IAPProduct.allCases.map { $0.rawValue }
            print("Requesting products with IDs: \(productIdentifiers)")
            
            let storeProducts = try await Product.products(for: Set(productIdentifiers))
            print("Received \(storeProducts.count) products from Store")
            
            self.products = storeProducts.compactMap { product in
                guard let iapProduct = IAPProduct(rawValue: product.id) else {
                    print("Unknown product ID: \(product.id)")
                    return nil
                }
                return ProductModel(
                    id: product.id,
                    product: product,
                    credits: iapProduct.credits
                )
            }.sorted { $0.credits < $1.credits }
            
            if products.isEmpty {
                print("No valid products found after mapping")
            } else {
                print("Successfully mapped \(products.count) products")
            }
            
            error = nil
        } catch {
            print("Failed to load products: \(error)")
            self.error = "Failed to load products: \(error.localizedDescription)"
            self.products = []
        }
    }
    
    func purchase(_ product: Product) async {
        #if DEBUG
        print("Attempting to purchase: \(product.id)")
        #endif
        
        guard creditsBalance < 999 else {
            error = "Maximum credits limit reached"
            return
        }
        
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        
        do {
            let result = try await product.purchase()
            
            #if DEBUG
            print("Purchase result: \(result)")
            #endif
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Add credits
                    if let iapProduct = IAPProduct(rawValue: transaction.productID) {
                        await addCredits(iapProduct.credits)
                    }
                    await transaction.finish()
                case .unverified(_, let error):
                    self.error = "Purchase verification failed: \(error.localizedDescription)"
                }
            case .userCancelled:
                break
            case .pending:
                self.error = "Purchase is pending approval"
            @unknown default:
                self.error = "Unknown purchase result"
            }
        } catch {
            #if DEBUG
            print("Purchase failed with error: \(error)")
            #endif
            self.error = "Purchase failed: \(error.localizedDescription)"
        }
    }
    
    func fetchCreditsFromFirestore() async throws {
        guard let userId = userId else {
            throw NSError(domain: "CreditsManager", 
                         code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
        }
        
        let userRef = db.collection("users").document(userId)
        let document = try await userRef.getDocument()
        
        if document.exists {
            if let credits = document.data()?["credits"] as? Int {
                await MainActor.run {
                    self.creditsBalance = credits
                    self.userDefaults.set(credits, forKey: self.creditsKey)
                }
            }
        } else {
            // If document doesn't exist, initialize with initialCreditsAmount
            try await userRef.setData([
                "credits": initialCreditsAmount,
                "createdAt": FieldValue.serverTimestamp()
            ])
            await MainActor.run {
                self.creditsBalance = initialCreditsAmount
                self.userDefaults.set(initialCreditsAmount, forKey: self.creditsKey)
            }
        }
    }
    
    func syncCreditsWithFirestore() async throws {
        guard let userId = userId else {
            throw NSError(domain: "CreditsManager", 
                         code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
        }
        
        let userRef = db.collection("users").document(userId)
        try await userRef.setData(["credits": creditsBalance], merge: true)
    }
    
    // MARK: - CreditsManagerProtocol
    
    func addCredits(_ amount: Int) async {
        creditsBalance += amount
        userDefaults.set(creditsBalance, forKey: creditsKey)
        
        // Sync with Firestore
        do {
            try await syncCreditsWithFirestore()
        } catch {
            print("syncCreditsWithFirestore credits with Firestore: \(error)")
            self.error = "Failed to sync credits: \(error.localizedDescription)"
        }
    }
    
    func useCredit() async -> Bool {
        guard creditsBalance > 0 else { return false }
        creditsBalance -= 1
        userDefaults.set(creditsBalance, forKey: creditsKey)
        
        // Sync with Firestore
        do {
            try await syncCreditsWithFirestore()
            return true
        } catch {
            print("Failed to sync credits with Firestore: \(error)")
            self.error = "Failed to sync credits: \(error.localizedDescription)"
            // Revert the local change if sync fails
            creditsBalance += 1
            userDefaults.set(creditsBalance, forKey: creditsKey)
            return false
        }
    }
    
    func addFreeCredits() async {
        await addCredits(freeCreditsAmount)
    }
    
    func initializeGuestCredits() async {
        // Set initial credits for guest users
        creditsBalance = initialCreditsAmount // This is already 20
        userDefaults.set(creditsBalance, forKey: creditsKey)
    }
}
