import SwiftUI
import Firebase

struct SplashScreen: View {
    @State private var isInitialized = false
    @State private var opacity = 0.0
    
    var body: some View {
        Group {
            if isInitialized {
                ContentView()
                    .transition(.opacity)
            } else {
                VStack {
                    Image("Shootsolo_Icon") // Your app icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                    Text("SHOOTSOLO")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.3)) {
                        opacity = 1.0
                    }
                    
                    // Check Firebase initialization status
                    Task {
                        // Wait for Firebase to be ready
                        while FirebaseApp.app() == nil {
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                        }
                        
                        // Add minimum splash duration
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                        
                        withAnimation {
                            isInitialized = true
                        }
                    }
                }
            }
        }
    }
} 