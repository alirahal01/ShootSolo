import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        
        // Set consistent video gravity
        view.videoPreviewLayer.videoGravity = .resizeAspect // Changed from resizeAspectFill
        
        // Lock the preview orientation to portrait
        view.videoPreviewLayer.connection?.videoOrientation = .portrait
        
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Update frame on rotation if needed
        uiView.videoPreviewLayer.frame = uiView.bounds
    }
}

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
    }
}

#Preview {
    CameraPreviewView(session: AVCaptureSession())
} 