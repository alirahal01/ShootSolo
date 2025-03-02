import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @Environment(\.dismiss) private var dismiss
    var onLoginStart: () -> Void
    var onLoginSuccess: () -> Void
    var showGuestOption: Bool = true
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 90)
            
            // Logo and App Name
            HStack {
                Image("Shootsolo_Icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
                
                Text("SHOOTSOLO")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            Spacer().frame(height: 10)
            
            // Subtitle
            Text("Voice controlled video\ncamera & filming assistant")
                .multilineTextAlignment(.center)
                .font(.title3)
                .foregroundColor(.black)
                .padding(.top, 5)
            
            Spacer()
            
            // Login Buttons
            VStack(spacing: 12) {
                Button(action: {
                    onLoginStart()
                    if let rootVC = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .flatMap({ $0.windows })
                        .first(where: { $0.isKeyWindow })?.rootViewController {
                        viewModel.loginWithGoogle(presentingViewController: rootVC) {
                            onLoginSuccess()
                            dismiss()
                        }
                    } else {
                        print("Error: Unable to find root view controller.")
                    }
                }) {
                    HStack {
                        Text("Login with Gmail")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.red)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    onLoginStart()
                    viewModel.loginWithApple {
                        onLoginSuccess()
                        dismiss()
                    }
                }) {
                    HStack {
                        Text("Login with Apple")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.red)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            
            // Only show guest option if showGuestOption is true
            if showGuestOption {
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
                
                // Guest Button
                Button(action: {
                    Task {
                        await AuthState.shared.continueAsGuest()
                        onLoginSuccess()
                    }
                }) {
                    Text("Continue as Guest")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            // Terms and Conditions
            VStack(spacing: 0) {
                Text("By using this app, you agree to")
                    .font(.system(size: 15))
                    .foregroundColor(.black)
                Button(action: {
                    if let url = URL(string: "https://shootsolo.com/terms-and-conditions.html") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("terms & conditions")
                        .font(.system(size: 15))
                        .foregroundColor(.red)
                }
            }
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .padding()
    }
}

#Preview {
    LoginView(onLoginStart: {}, onLoginSuccess: {})
} 
