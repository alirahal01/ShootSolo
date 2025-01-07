import SwiftUI

struct SaveTakeDialog: View {
    let takeNumber: Int
    let onSave: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Save Take?")
                .font(.headline)
            
            Text("Listening for YES or NO...")
                .font(.headline)
                .bold()
                .foregroundColor(.gray)
            
            HStack(spacing: 20) {
                Button(action: onDiscard) {
                    Text("No")
                        .frame(width: 100)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: onSave) {
                    Text("Yes")
                        .frame(width: 100)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding(30)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

#Preview {
    SaveTakeDialog(
        takeNumber: 1,
        onSave: {},
        onDiscard: {}
    )
} 
