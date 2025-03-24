import SwiftUI
import PhotosUI

struct CameraBottomControls: View {
    @Binding var isRecording: Bool
    @Binding var currentTake: Int
    @State private var showPhotoLibraryAlert = false
    var startRecording: () -> Void
    var stopRecording: () -> Void
    var switchCamera: () -> Void

    var body: some View {
        HStack(spacing: 40) {
            // Gallery Button
            if !isRecording {
                Button(action: {
                    checkPhotoLibraryAccess()
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
                .alert("Photo Library Access Required", isPresented: $showPhotoLibraryAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Open Settings") {
                        openSettings()
                    }
                } message: {
                    Text("Please enable photo library access in Settings to view your gallery")
                }
            }
            
            // Record Button
            Button(action: {
                if isRecording {
                    Task {
                        await stopRecording()
                    }
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
    
    private func checkPhotoLibraryAccess() {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized, .limited:
            openPhotoGallery()
        case .denied, .restricted:
            showPhotoLibraryAlert = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        openPhotoGallery()
                    } else {
                        showPhotoLibraryAlert = true
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func openPhotoGallery() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
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