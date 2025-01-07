import AVFoundation
import Photos

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isRecording = false
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentCamera: AVCaptureDevice?
    private var currentPosition: AVCaptureDevice.Position = .back
    private var currentVideoUrl: URL?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        currentCamera = device
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            // Add audio input
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            }
            
            videoOutput = AVCaptureMovieFileOutput()
            if let videoOutput = videoOutput, session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        } catch {
            print("Failed to setup camera: \(error.localizedDescription)")
        }
    }
    
    func toggleFlash(isOn: Bool) {
        guard let device = currentCamera,
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = isOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Flash could not be toggled: \(error.localizedDescription)")
        }
    }
    
    func switchCamera() {
        session.beginConfiguration()
        
        // Remove existing input
        if let currentInput = session.inputs.first as? AVCaptureDeviceInput {
            session.removeInput(currentInput)
        }
        
        // Switch camera position
        currentPosition = currentPosition == .back ? .front : .back
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else { return }
        currentCamera = newCamera
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            }
        } catch {
            print("Error switching cameras: \(error.localizedDescription)")
        }
        
        session.commitConfiguration()
    }
    
    func startRecording() {
        guard let videoOutput = videoOutput else { return }
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent("take\(Date().timeIntervalSince1970).mov")
        currentVideoUrl = fileUrl
        videoOutput.startRecording(to: fileUrl, recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording() {
        videoOutput?.stopRecording()
        isRecording = false
    }
    
    func saveTake() {
        guard let videoUrl = currentVideoUrl else { return }
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { return }
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoUrl)
            } completionHandler: { success, error in
                if success {
                    print("Video saved to gallery")
                } else if let error = error {
                    print("Error saving video: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func discardTake() {
        if let videoUrl = currentVideoUrl {
            try? FileManager.default.removeItem(at: videoUrl)
        }
        currentVideoUrl = nil
    }
    
    func setZoomFactor(_ zoomFactor: CGFloat) {
        guard let device = currentCamera else { return }
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = max(1.0, min(zoomFactor, device.activeFormat.videoMaxZoomFactor))
            device.unlockForConfiguration()
        } catch {
            print("Failed to set zoom factor: \(error.localizedDescription)")
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording video: \(error.localizedDescription)")
        }
    }
}