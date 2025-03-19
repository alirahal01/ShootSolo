import SwiftUI

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
                    withAnimation(.easeIn(duration: 0.5)) {
                        opacity = 1.0
                    }
                    
                    // Perform async initialization
                    Task {
                        // Add any required async initialization here
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second minimum splash
                        
                        withAnimation {
                            isInitialized = true
                        }
                    }
                }
            }
        }
    }
} 