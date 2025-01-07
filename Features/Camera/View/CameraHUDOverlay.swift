import SwiftUI

struct CameraHUDOverlay: View {
    @Binding var isRecording: Bool
    @Binding var zoomFactor: CGFloat
    var cameraManager: CameraManager

    var body: some View {
        VStack {
            Spacer()
            
            if !isRecording {
                // Zoom Control
                ZoomControlView(zoomFactor: $zoomFactor)
                    .onChange(of: zoomFactor) { newValue in
                        cameraManager.setZoomFactor(newValue)
                    }
                    .padding(.bottom, 20)
                
                // Message HUD
                MessageHUDView()
                    .padding(.bottom, 20)
            }
        }
    }
}

#Preview {
    CameraHUDOverlay(isRecording: .constant(false), zoomFactor: .constant(1.0), cameraManager: CameraManager())
} 
