//
//  MessageHudView.swift
//  VOICETEST
//
//  Created by ali rahal on 27/12/2024.
//

import Foundation
import SwiftUI

struct MessageHUDView: View {
    var body: some View {
        Text("Ready to record.\nSay “HEY ACTION” to start,\n“HEY CUT” to stop.")
            .font(.system(size: 14))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding()
            .background(Color.black.opacity(0.35))
            .cornerRadius(40)
    }
}
