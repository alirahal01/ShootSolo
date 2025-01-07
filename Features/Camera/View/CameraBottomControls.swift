import SwiftUI
import PhotosUI

struct CameraBottomControls: View {
    @Binding var isRecording: Bool
    @Binding var currentTake: Int
    var startRecording: () -> Void
    var stopRecording: () -> Void
    var switchCamera: () -> Void

    var body: some View {
        HStack(spacing: 40) {
            // Gallery Button
            if !isRecording {
                Button(action: {
                    openPhotoGallery()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 55, height: 55)
                        
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Record Button
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.white)
                        .frame(width: 70, height: 70)
                    
                    if isRecording {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .cornerRadius(4)
                    } else {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                    }
                }
            }
            
            // Toggle Camera Button
            if !isRecording {
                Button(action: {
                    switchCamera()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 55, height: 55)
                        
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding()
        .background(Color.clear)
    }
    
    private func openPhotoGallery() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    CameraBottomControls(
        isRecording: .constant(false),
        currentTake: .constant(1),
        startRecording: {},
        stopRecording: {},
        switchCamera: {}
    )
} 