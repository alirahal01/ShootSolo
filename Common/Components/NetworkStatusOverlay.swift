import SwiftUI
import UIKit

struct NetworkStatusOverlay: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var isAnimating = false
    @State private var isPulsing = false
    @State private var rotationDegrees = 0.0
    
    var body: some View {
        ZStack {
            if !networkMonitor.isConnected {
                // Full screen semi-transparent background with red tint
                Color.gray.opacity(0.8)
                    .edgesIgnoringSafeArea(.all)
                
                // Animated background
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: isPulsing ? 300 : 100)
                    .animation(
                        Animation.easeInOut(duration: 2)
                            .repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                
                // Offline message container
                VStack(spacing: 20) {
                    // Animated icon
                    ZStack {
                        // Outer circle
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 90, height: 90)
                            .scaleEffect(isAnimating ? 1.1 : 0.9)
                            .animation(
                                Animation.easeInOut(duration: 1.2)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                        
                        // Wifi slash icon
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(rotationDegrees))
                            .animation(
                                Animation.easeInOut(duration: 0.5)
                                    .repeatCount(3, autoreverses: true),
                                value: rotationDegrees
                            )
                    }
                    
                    Text("Network Connection Lost")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    
                    Text("Your device is currently offline. Some features may be unavailable until connection is restored.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .padding(.horizontal)
                    
                    // Retry button with animation
                    Button(action: {
                        // Provide haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        
                        // Trigger rotation animation
                        withAnimation {
                            rotationDegrees += 360
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .bold))
                            Text("Check Connection")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        )
                        .foregroundColor(.red)
                    }
                    .padding(.top, 10)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.red.opacity(0.8), Color.red.opacity(0.9)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                )
                .padding(.horizontal, 40)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: networkMonitor.isConnected)
        .onAppear {
            isAnimating = true
            isPulsing = true
        }
    }
}

struct NetworkStatusOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3).edgesIgnoringSafeArea(.all)
            Text("App Content")
            NetworkStatusOverlay()
        }
    }
} 
