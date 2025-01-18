import SwiftUI
import StoreKit

@main
struct ShootSoloApp: App {
    // Initialize transaction listener
    init() {
        // Observe transactions
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
} 