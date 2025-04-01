//
//  MessageHudView.swift
//  VOICETEST
//
//  Created by ali rahal on 27/12/2024.
//

import Foundation
import SwiftUI

struct MessageHUDView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject var speechRecognizer: SpeechRecognizer
    let context: CommandContext
    
    var body: some View {
        HStack(spacing: 12) {
            // Speech Recognizer Status
            SpeechRecognizerStatusView(speechRecognizer: speechRecognizer, context: context)
            
            // Command Instructions or Status
            Text(statusText)
                .font(.system(size: 14))
                .foregroundColor(textColor)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.35))
        .cornerRadius(40)
    }
    
    private var statusText: String {
        if speechRecognizer.isInitializing {
            return "Initializing..."
        } else if speechRecognizer.hasError {
            return "<- Tap to restart listening"
        } else if !speechRecognizer.isListening {
            return "<- Tap to start listening"
        } else {
            switch context {
            case .camera:
                return "Listening...\nSay \"\(settingsManager.settings.selectedStartKeyword.rawValue)\" to start,\n\"\(settingsManager.settings.selectedStopKeyword.rawValue)\" to stop."
            case .saveDialog:
                return "Listening...\nSay \"yes\" to save,\n\"no\" to discard."
            }
        }
    }
    
    private var textColor: Color {
        if speechRecognizer.hasError {
            return .red
        } else  {
            return .white
        }
    }
}

#Preview {
    ZStack {
        Color.gray // Background for preview
        MessageHUDView(
            speechRecognizer: SpeechRecognizer(),
            context: .camera
        )
    }
}
