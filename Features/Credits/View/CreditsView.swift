import SwiftUI
import StoreKit

struct CreditsView: View {
    @StateObject private var creditsManager = CreditsManager.shared
    @StateObject private var adViewModel = RewardedAdViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingError = false
    @State private var isLoadingAd = false
    
    // Debug info
    #if DEBUG
    @State private var isTestEnvironment = false
    #endif
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with close button
            HStack {
                VStack(spacing: 4) {
                    Text("Out of credits?")
                        .font(.title2)
                        .bold()
                    Text("Buy more:")
                        .font(.title3)
                }
                .frame(maxWidth: .infinity)
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal)
            
            if creditsManager.isLoadingProducts {
                ProgressView("Loading products...")
            } else if creditsManager.products.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Text("No products available")
                        .font(.headline)
                    Button("Retry") {
                        Task {
                            await creditsManager.loadProducts()
                        }
                    }
                }
            } else {
                // Credits packages
                VStack(spacing: 12) {
                    ForEach(creditsManager.products) { product in
                        PurchaseButton(
                            product: product.product,
                            credits: product.credits,
                            isLoading: creditsManager.purchaseInProgress
                        ) {
                            Task {
                                await creditsManager.purchase(product.product)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Separator
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                    Text("OR")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Free credits button
                Button {
                    handleWatchAd()
                } label: {
                    HStack {
                        Text("5 credits for FREE")
                            .bold()
                        Spacer()
                        if isLoadingAd {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Watch Ad")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoadingAd)
                .padding(.horizontal)
            }
            
            #if DEBUG
            // Debug info
            VStack {
                Text("Environment: \(isTestEnvironment ? "Testing" : "Production")")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("Balance: \(creditsManager.creditsBalance)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            #endif
        }
        .padding(.vertical)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(creditsManager.error ?? "Unknown error")
        }
        .onChange(of: creditsManager.error) { error in
            showingError = error != nil
        }
        .onAppear {
            #if DEBUG
            // Check if we're running with StoreKit configuration
            isTestEnvironment = Bundle.main.path(
                forResource: "StoreKitConfig",
                ofType: "storekit"
            ) != nil
            print("Products available: \(creditsManager.products.map { $0.id })")
            #endif
        }
    }
    
    private func handleWatchAd() {
        isLoadingAd = true
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            adViewModel.showAd(from: rootViewController) { success in
                isLoadingAd = false
                if success {
                    Task {
                        await creditsManager.addFreeCredits()
                    }
                }
            }
        } else {
            isLoadingAd = false
        }
    }
}

struct PurchaseButton: View {
    let product: Product
    let credits: Int
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text("\(credits) credits")
                    .bold()
                Spacer()
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(product.displayPrice)
                        .bold()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
}

#Preview {
    CreditsView()
} 
