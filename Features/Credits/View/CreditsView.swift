import SwiftUI
import StoreKit

struct CreditsView: View {
    @StateObject private var creditsManager = CreditsManager.shared
    @StateObject private var adViewModel = RewardedAdViewModel.shared
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
                
                // If there's no ad loaded and not currently loading, trigger a load
                if adViewModel.rewardedAd == nil && !adViewModel.isLoading {
                    adViewModel.loadAd()
                }
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
                .withNetworkStatusOverlay()
            }
        }
        .withNetworkStatusOverlay()
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
                    
                    // Add divider and "OR" text
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                        Text("OR")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .padding(.vertical)
                    
                    // Watch Ad Button
                    Button(action: handleWatchAd) {
                        HStack {
                            Text("5 credits for ")
                                .foregroundColor(.white)
                            Text("FREE")
                                .bold()
                                .foregroundColor(.white)
                            Spacer()
                            if isLoadingAd {
                                // Show when ad is being presented
                                ProgressView()
                                    .tint(.white)
                            } else if adViewModel.isLoading {
                                // Show when next ad is loading
                                HStack(spacing: 4) {
                                    Text("Loading Next Ad")
                                        .font(.subheadline)
                                    ProgressView()
                                        .tint(.white)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Text("Watch Ad")
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 20))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            Group {
                                if adViewModel.isLoading {
                                    Color.green.opacity(0.3) // Loading next ad - dimmed green
                                } else if adViewModel.rewardedAd == nil {
                                    Color.gray.opacity(0.5) // No ad available - gray
                                } else {
                                    Color.green // Ready to show - full green
                                }
                            }
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(adViewModel.rewardedAd == nil || isLoadingAd)
                    
                    // Error messages
                    let adError = adViewModel.lastFailureReason.userMessage
                    let creditsError = creditsManager.error ?? ""
                    
                    if !adError.isEmpty && !creditsError.isEmpty {
                        if adError.contains("No internet connection") && creditsError.contains("No internet connection") {
                            Text("No internet connection. Please check your connection and try again.")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 4)
                        } else {
                            Text("\(adError) | \(creditsError)")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 4)
                        }
                    } else if !adError.isEmpty {
                        Text(adError)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    } else if !creditsError.isEmpty {
                        Text(creditsError)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
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
        guard !isLoadingAd else { return }
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
