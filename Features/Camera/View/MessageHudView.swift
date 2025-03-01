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
            
            // Command Instructions
            Text("Say \"\(settingsManager.settings.selectedStartKeyword.rawValue)\" to start,\n\"\(settingsManager.settings.selectedStopKeyword.rawValue)\" to stop.")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.35))
        .cornerRadius(40)
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
