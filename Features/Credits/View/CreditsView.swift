import SwiftUI
import StoreKit

struct CreditsView: View {
    @StateObject private var creditsManager = CreditsManager.shared
    @StateObject private var adViewModel = RewardedAdViewModel()
    @EnvironmentObject private var authState: AuthState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    @State private var showingError = false
    @State private var isLoadingAd = false
    @State private var showingLoginView = false
    
    // Debug info
    #if DEBUG
    @State private var isTestEnvironment = false
    #endif
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    creditsContent
                }
                .padding()
            }
            .navigationTitle("Credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Check if guest user and show login
            if authState.isGuestUser {
                showingLoginView = true
            }
            
            #if DEBUG
            // Check if we're running with StoreKit configuration
            isTestEnvironment = Bundle.main.path(
                forResource: "StoreKitConfig",
                ofType: "storekit"
            ) != nil
            print("Products available: \(creditsManager.products.map { $0.id })")
            #endif
        }
        .fullScreenCover(isPresented: $showingLoginView) {
            LoginView(
                onLoginStart: {},
                onLoginSuccess: {
                    showingLoginView = false
                    // Refresh credits after login
                    Task {
                        try? await creditsManager.fetchCreditsFromFirestore()
                    }
                },
                showGuestOption: false
            )
        }
    }
    
    private var creditsContent: some View {
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
                
                Spacer()
                
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
        }
        .padding(.vertical)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(creditsManager.error ?? "Unknown error")
        }
        .alert("Session Expired", isPresented: $authState.showAuthAlert) {
            Button("Sign In") {
                dismiss()
                authState.isLoggedIn = false
            }
        } message: {
            Text("Your session has expired. Please sign in again to continue.")
        }
        .onChange(of: creditsManager.error) { error in
            showingError = error != nil
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
