import SwiftUI
import GoogleMobileAds

struct RewardedAdView: View {
    @StateObject private var adViewModel = RewardedAdViewModel()
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Watch an Ad to Earn Rewards")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let error = adViewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                showRewardedAd()
            }) {
                HStack {
                    if adViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.trailing, 8)
                    }
                    
                    Text(buttonTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(buttonBackground)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isButtonEnabled)
            .padding(.horizontal)
        }
        .padding()
        .alert("Ad Status", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            if adViewModel.rewardedAd == nil && !adViewModel.isLoading {
                adViewModel.loadAd()
            }
        }
    }
    
    private var isButtonEnabled: Bool {
        !adViewModel.isLoading && adViewModel.rewardedAd != nil
    }
    
    private var buttonTitle: String {
        if adViewModel.isLoading {
            return "Loading Ad..."
        } else if adViewModel.rewardedAd == nil {
            return "Ad Not Ready"
        } else {
            return "Watch Ad"
        }
    }
    
    private var buttonBackground: Color {
        isButtonEnabled ? Color.blue : Color.gray.opacity(0.5)
    }
    
    private func showRewardedAd() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            alertMessage = "Cannot present ad at this time"
            showAlert = true
            return
        }
        
        adViewModel.showAd(from: rootViewController) { success in
            if success {
                alertMessage = "Thank you for watching! Reward has been credited."
            } else {
                alertMessage = "Failed to complete ad viewing"
            }
            showAlert = true
        }
    }
}
