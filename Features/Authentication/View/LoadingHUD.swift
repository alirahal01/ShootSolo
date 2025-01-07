import SwiftUI

struct LoadingHUD: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
                .padding()
            Text("Logging in...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(width: 200, height: 200)
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
        .shadow(radius: 10)
    }
}

#Preview {
    LoadingHUD()
} 