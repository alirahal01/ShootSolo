import Foundation
import StoreKit

@MainActor
class CreditsManager: ObservableObject, CreditsManagerProtocol {
    static let shared = CreditsManager()
    
    @Published private(set) var products: [ProductModel] = []
    @Published var creditsBalance: Int = 0
    @Published private(set) var purchaseInProgress = false
    @Published var error: String?
    @Published private(set) var isLoadingProducts = false
    
    private let userDefaults = UserDefaults.standard
    private let creditsKey = "user_credits_balance"
    private let freeCreditsAmount = 5
    
    init() {
        creditsBalance = userDefaults.integer(forKey: creditsKey)
        
        // Start observing transactions
        Task {
            await observeTransactions()
        }
        
        // Load products
        Task {
            await loadProducts()
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
    
    // MARK: - CreditsManagerProtocol
    
    func addCredits(_ amount: Int) async {
        creditsBalance += amount
        userDefaults.set(creditsBalance, forKey: creditsKey)
    }
    
    func useCredit() async -> Bool {
        guard creditsBalance > 0 else { return false }
        creditsBalance -= 1
        userDefaults.set(creditsBalance, forKey: creditsKey)
        return true
    }
    
    func addFreeCredits() async {
        // Add free credits directly since the ad completion is handled in CreditsView
        await addCredits(freeCreditsAmount)
    }
}
