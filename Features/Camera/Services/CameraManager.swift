import AVFoundation
import Photos

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isRecording = false
    @Published var permissionGranted = false
    
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentCamera: AVCaptureDevice?
    private var currentPosition: AVCaptureDevice.Position = .back
    private var currentVideoUrl: URL?
    
    private let settingsManager = SettingsManager.shared
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    private func checkPermissions() {
        // Check camera permissions
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Camera permissions granted, now check photo library permissions
            checkPhotoLibraryPermissions()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.checkPhotoLibraryPermissions()
                    }
                }
            }
        default:
            break
        }
    }
    
    private func checkPhotoLibraryPermissions() {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized, .limited:
            setupCamera()
            DispatchQueue.main.async {
                self.permissionGranted = true
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        self?.setupCamera()
                        self?.permissionGranted = true
                    }
                }
            }
        default:
            break
        }
    }
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get camera device")
            return
        }
        currentCamera = device
        
        session.beginConfiguration()
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                print("Could not add video input")
            }
            
            // Add audio input
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                } else {
                    print("Could not add audio input")
                }
            }
            
            videoOutput = AVCaptureMovieFileOutput()
            if let videoOutput = videoOutput, session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            } else {
                print("Could not add video output")
            }
            
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
                // Play ready sound on main thread after camera is set up
                DispatchQueue.main.async {
                    SoundManager.shared.playReadySound()
                }
            }
        } catch {
            print("Failed to setup camera: \(error.localizedDescription)")
            session.commitConfiguration()
        }
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, 
                                      mode: .default,
                                      options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    func toggleFlash(isOn: Bool) {
        guard let device = currentCamera,
              device.hasTorch else {
            print("Flash not available")
            return
        }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = isOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Flash could not be toggled: \(error.localizedDescription)")
        }
    }
    
    func switchCamera() {
        guard permissionGranted else { return }
        
        session.beginConfiguration()
        
        // Remove existing input
        session.inputs.forEach { input in
            session.removeInput(input)
        }
        
        // Switch camera position
        currentPosition = currentPosition == .back ? .front : .back
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else {
            print("Failed to get new camera device")
            session.commitConfiguration()
            return
        }
        currentCamera = newCamera
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            } else {
                print("Could not add new camera input")
            }
            
            // Re-add audio input
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            }
            
            session.commitConfiguration()
            
            // Play ready sound after camera switch is complete
            DispatchQueue.main.async {
                SoundManager.shared.playReadySound()
            }
            
        } catch {
            print("Error switching cameras: \(error.localizedDescription)")
            session.commitConfiguration()
        }
    }
    
    private func generateFileName() -> String {
        let fileFormat = settingsManager.settings.fileNameFormat
        
        // If filename is empty or invalid, use default date format
        if fileFormat.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            return "video_\(dateFormatter.string(from: Date())).mov"
        }
        
        return fileFormat + ".mov"
    }
    
    func startRecording() {
        guard permissionGranted else { return }
        guard let videoOutput = videoOutput else {
            print("Video output not available")
            return
        }
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent(generateFileName())
        currentVideoUrl = fileUrl
        
        // Start recording on a background queue
        DispatchQueue.global(qos: .userInitiated).async {
            videoOutput.startRecording(to: fileUrl, recordingDelegate: self)
            DispatchQueue.main.async {
                self.isRecording = true
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        videoOutput?.stopRecording()
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    func saveTake() {
        guard let videoUrl = currentVideoUrl else {
            print("No video URL available")
            return
        }
        
        guard FileManager.default.fileExists(at: videoUrl.path) else {
            print("Video file doesn't exist at path: \(videoUrl.path)")
            return
        }
        
        // Ensure we're on the main thread for UI updates
        DispatchQueue.main.async {
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoUrl)
                request?.creationDate = Date()
            } completionHandler: { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        print("Video saved successfully to gallery")
                        self?.cleanupTempFile()
                    } else {
                        print("Error saving video: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        }
    }
    
    func discardTake() {
        cleanupTempFile()
    }
    
    private func cleanupTempFile() {
        if let videoUrl = currentVideoUrl {
            do {
                try FileManager.default.removeItem(at: videoUrl)
                currentVideoUrl = nil
            } catch {
                print("Error cleaning up temp file: \(error.localizedDescription)")
            }
        }
    }
    
    func setZoomFactor(_ zoomFactor: CGFloat) {
        guard let device = currentCamera else {
            print("Camera device not available")
            return
        }
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = max(1.0, min(zoomFactor, device.activeFormat.videoMaxZoomFactor))
            device.unlockForConfiguration()
        } catch {
            print("Failed to set zoom factor: \(error.localizedDescription)")
        }
    }
}

extension FileManager {
    func fileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Optional: Handle recording start
        print("Started recording to: \(fileURL.path)")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording video: \(error.localizedDescription)")
            return
        }
        
        // Update currentVideoUrl on main thread
        DispatchQueue.main.async {
            self.currentVideoUrl = outputFileURL
        }
    }
}
