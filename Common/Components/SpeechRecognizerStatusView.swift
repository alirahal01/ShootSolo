import SwiftUI

struct SpeechRecognizerStatusView: View {
    @ObservedObject var speechRecognizer: SpeechRecognizer
    var context: CommandContext

    var body: some View {
        HStack {
            Circle()
                .fill(speechRecognizer.isListening ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            
            Text(speechRecognizer.isListening ? "Listening..." : "Not Listening")
                .font(.caption)
                .foregroundColor(.gray)
            
            if !speechRecognizer.isListening {
                Button(action: {
                    speechRecognizer.startListening(context: context)
                }) {
                    Text("Retry")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.leading, 5)
            }
        }
        .padding(5)
        .background(Color.white.opacity(0.8))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

#Preview {
    SpeechRecognizerStatusView(speechRecognizer: SpeechRecognizer(), context: .camera)
} 