import SwiftUI

struct SaveTakeDialog: View {
    let takeNumber: Int
    let onSave: () -> Void
    let onDiscard: () -> Void
    @ObservedObject var speechRecognizer: SpeechRecognizer
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Save Take \(takeNumber)?")
                .font(.headline)
            
            if let errorMessage = speechRecognizer.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            } else {
                HStack {
                    SpeechRecognizerStatusView(speechRecognizer: speechRecognizer, context: .saveDialog)
                    Text(statusText)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.gray)
                }
            }
            
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
        .onAppear {
            SoundManager.shared.playSaveTakeSound()
        }
    }
    
    private var statusText: String {
        if speechRecognizer.hasError {
            return "<- Tap refresh to start listening"
        } else {
            return "Listening for YES or NO..."
        }
    }
}

#Preview {
    SaveTakeDialog(
        takeNumber: 1,
        onSave: {},
        onDiscard: {},
        speechRecognizer: SpeechRecognizer()
    )
}
