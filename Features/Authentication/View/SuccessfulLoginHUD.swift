import SwiftUI

struct SuccessfulLoginHUD: View {
    var body: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.green)
                .padding()
            Text("Login Successful!")
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
    SuccessfulLoginHUD()
} 