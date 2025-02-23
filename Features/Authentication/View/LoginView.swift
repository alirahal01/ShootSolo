import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
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
            
            // Guest Button - Only show if showGuestOption is true
            if showGuestOption {
                Button(action: {
                    AuthState.shared.continueAsGuest()
                    onLoginSuccess()
                }) {
                    Text("Continue as Guest")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            // Terms and Conditions
            VStack {
                HStack(spacing: 0) {
                    Text("By using this app, you agree to ")
                        .font(.callout)
                    Text("terms & conditions")
                        .font(.callout)
                        .foregroundColor(.red)
                        .onTapGesture {
                            if let url = URL(string: "https://shootsolo.com/terms-and-conditions.html") {
                                UIApplication.shared.open(url)
                            }
                        }
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 40)
            .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    LoginView(onLoginStart: {}, onLoginSuccess: {})
} 
