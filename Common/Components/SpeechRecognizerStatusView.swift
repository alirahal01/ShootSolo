import SwiftUI

struct SpeechRecognizerStatusView: View {
    @ObservedObject var speechRecognizer: SpeechRecognizer
    let context: CommandContext
    
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: {
            // Restart listening regardless of whether there's an error or it's just not listening
            if !speechRecognizer.isListening || speechRecognizer.hasError {
                // No need to call resetError() as startListening() handles error reset internally
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
                    if speechRecognizer.isInitializing {
                        // Show loading indicator during initialization
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else if speechRecognizer.hasError {
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
        .disabled(speechRecognizer.isInitializing) // Disable the button during initialization
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
        if speechRecognizer.isInitializing {
            return .red // Use orange color to indicate initializing state
        }
        // Only green when actively listening with no errors, red in all other cases
        return (speechRecognizer.isListening && !speechRecognizer.hasError) ? .green : .red
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
            
            // Inactive state (will show as red)
            let inactiveRecognizer = SpeechRecognizer()
            SpeechRecognizerStatusView(speechRecognizer: inactiveRecognizer, context: .camera)
        }
        .padding()
        .background(Color.black)
    }
}
