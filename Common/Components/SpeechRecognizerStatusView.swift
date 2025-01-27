import SwiftUI

struct SpeechRecognizerStatusView: View {
    @ObservedObject var speechRecognizer: SpeechRecognizer
    let context: CommandContext
    
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: {
            if speechRecognizer.hasError {
                speechRecognizer.startListening(context: context)
            }
        }) {
            ZStack {
                // Background circle
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 25, height: 25)
                
                // Icon
                Group {
                    if speechRecognizer.hasError {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "waveform")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .opacity(speechRecognizer.isListening ? 1 : 0.5)
                            .scaleEffect(isAnimating ? 0.9 : 0.8)
                    }
                }
            }
        }
        .onChange(of: speechRecognizer.isListening) { isListening in
            if isListening {
                // Start animation when listening
                withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                    isAnimating = true
                }
            } else {
                // Stop animation when not listening
                withAnimation {
                    isAnimating = false
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        if speechRecognizer.hasError {
            return .red
        }
        return speechRecognizer.isListening ? .green : .gray.opacity(0.8)
    }
}

// Preview
#Preview {
    Group {
        HStack(spacing: 20) {
            // Active state
            let activeRecognizer = SpeechRecognizer()
            SpeechRecognizerStatusView(speechRecognizer: activeRecognizer, context: .camera)
                .onAppear {
                    activeRecognizer.isListening = true
                }
            
            // Error state
            let errorRecognizer = SpeechRecognizer()
            SpeechRecognizerStatusView(speechRecognizer: errorRecognizer, context: .camera)
                .onAppear {
                    errorRecognizer.hasError = true
                    errorRecognizer.errorMessage = "Error"
                }
            
            // Inactive state
            let inactiveRecognizer = SpeechRecognizer()
            SpeechRecognizerStatusView(speechRecognizer: inactiveRecognizer, context: .camera)
        }
        .padding()
        .background(Color.black)
    }
}
