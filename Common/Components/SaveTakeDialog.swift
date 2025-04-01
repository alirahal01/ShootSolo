import SwiftUI
import Combine

struct SaveTakeDialog: View {
    let takeNumber: Int
    let onSave: () -> Void
    let onDiscard: () -> Void
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @State private var hasPlayedSound = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Save Take \(takeNumber)?")
                .font(.headline)
            
            if speechRecognizer.hasError {
                Text(speechRecognizer.errorMessage ?? "Error occurred")
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
        .onChange(of: speechRecognizer.isListening) { isListening in
            checkAndPlaySound()
        }
        .onChange(of: speechRecognizer.hasError) { hasError in
            checkAndPlaySound()
        }
        .onAppear {
            hasPlayedSound = false
            checkAndPlaySound()
            
            // Force start listening in save dialog context
            speechRecognizer.startListening(context: .saveDialog)
        }
    }
    
    private func checkAndPlaySound() {
        // Only play sound once when conditions are met
        if !hasPlayedSound && 
           speechRecognizer.isListening && 
           !speechRecognizer.hasError {
            SoundManager.shared.playSaveTakeSound(speechRecognizer: speechRecognizer)
            hasPlayedSound = true
        }
    }
    
    private var statusText: String {
        if speechRecognizer.isInitializing {
            return "Starting up..."
        } else if !speechRecognizer.isListening {
            return "<- Tap to start listening"
        } else if speechRecognizer.isWaitingForSpeech {
            return "Listening for YES or NO..."
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
