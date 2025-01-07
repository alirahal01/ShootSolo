import SwiftUI

struct HUDTopBar: View {
    let credits: Int
    
    var body: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "gear")
            }
            Spacer()
            Text("Credits: \(credits)")
        }
        .padding()
        .foregroundColor(.white)
    }
}

struct HUDBottomControls: View {
    @Binding var isRecording: Bool
    let currentTake: Int
    let onRecordTap: () -> Void
    
    var body: some View {
        HStack {
            Text("Take \(currentTake)")
            Spacer()
            Button(action: onRecordTap) {
                Circle()
                    .fill(isRecording ? Color.red : Color.white)
                    .frame(width: 60, height: 60)
            }
            Spacer()
            Button(action: {}) {
                Image(systemName: "arrow.clockwise")
            }
        }
        .padding()
        .foregroundColor(.white)
    }
} 