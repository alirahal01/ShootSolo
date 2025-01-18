import SwiftUI
import Firebase
import FirebaseAuth

struct ContentView: View {
    @StateObject private var authState = AuthState()
    @State private var isLoading: Bool = true
    @State private var showLoaderHUD: Bool = false
    @State private var showSuccessHUD: Bool = false
//    private var cameraViewModel = CameraViewModel()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some View {
        ZStack {
            Group {
                if isLoading {
//                    LoadingView() 
                } else if authState.isLoggedIn {
                    NavigationView {
                        CameraView()
                            .padding([.top, .bottom], 16)
                            .edgesIgnoringSafeArea(.all)
                    }
                } else {
                    LoginView(onLoginStart: {
                        self.showLoaderHUD = true
                    }, onLoginSuccess: {
                        self.showLoaderHUD = false
                        self.showSuccessHUD = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.authState.isLoggedIn = true
                            self.showSuccessHUD = false
                        }
                    })
                }
            }
            
            if showLoaderHUD {
                LoadingHUD()
                    .transition(.opacity)
            }
            
            if showSuccessHUD {
                SuccessfulLoginHUD()
                    .transition(.opacity)
            }
        }
        .onAppear {
            checkAuthState()
        }
        .environmentObject(authState)
    }
    
    private func checkAuthState() {
        DispatchQueue.main.async {
            let currentUser = Auth.auth().currentUser
            self.authState.isLoggedIn = (currentUser != nil)
            self.isLoading = false
            print("Auth state checked: \(self.authState.isLoggedIn ? "Logged In" : "Not Logged In")")
        }
    }
}

#Preview {
    ContentView()
}
