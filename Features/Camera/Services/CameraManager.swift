import AVFoundation
import Photos

extension CameraManager: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Only process audio samples
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              CMFormatDescriptionGetMediaType(formatDesc) == kCMMediaType_Audio
        else {
            return
        }
        
        // Debug: Print audio format details
        if let audioDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(audioDesc)?.pointee
//            print("🎤 Audio format - sample rate: \(asbd?.mSampleRate ?? 0), channels: \(asbd?.mChannelsPerFrame ?? 0)")
        }
        
        // Forward audio samples to speech recognizer
        speechRecognizer?.appendAudioSampleBuffer(sampleBuffer)
    }
}

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isRecording = false
    @Published var permissionGranted = false
    @Published var isReady = false
    @Published var microphonePermissionGranted = false
    
    weak var speechRecognizer: SpeechRecognizer?
    
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentCamera: AVCaptureDevice?
    private var currentPosition: AVCaptureDevice.Position = .back
    private var currentVideoUrl: URL?
    private let audioDataOutput = AVCaptureAudioDataOutput()
    private let settingsManager = SettingsManager.shared
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func setZoomFactor(_ zoomFactor: CGFloat) {
        guard let device = currentCamera,
              let videoConnection = videoOutput?.connection(with: .video) else {
            print("Camera device or video connection not available")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // Get the device's permissible zoom range
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = device.maxAvailableVideoZoomFactor
            
            // Clamp the requested zoom factor within device limits
            let clampedZoom = max(minZoom, min(zoomFactor, maxZoom))
            
            // Set the device's zoom factor
            device.videoZoomFactor = clampedZoom
            
            // Ensure the videoScaleAndCropFactor is within limits
            videoConnection.videoScaleAndCropFactor = min(clampedZoom, videoConnection.videoMaxScaleAndCropFactor)
            
            device.unlockForConfiguration()
            
            print("Zoom updated to \(clampedZoom).")
        } catch {
            print("Failed to set zoom factor: \(error.localizedDescription)")
        }
    }

    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            checkMicrophonePermissions()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.checkMicrophonePermissions()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.permissionGranted = false
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.permissionGranted = false
            }
        @unknown default:
            break
        }
    }
    
    private func checkMicrophonePermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            DispatchQueue.main.async { [weak self] in
                self?.microphonePermissionGranted = true
                self?.permissionGranted = true
                self?.setupCamera()
            }
            checkPhotoLibraryPermissions()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.microphonePermissionGranted = true
                        self?.permissionGranted = true
                        self?.setupCamera()
                    }
                    self?.checkPhotoLibraryPermissions()
                } else {
                    DispatchQueue.main.async {
                        self?.microphonePermissionGranted = false
                        self?.permissionGranted = false
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.microphonePermissionGranted = false
                self.permissionGranted = false
            }
        @unknown default:
            break
        }
    }
    
    private func checkPhotoLibraryPermissions() {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized, .limited:
            break
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { _ in }
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }
    
    func setSpeechRecognizer(_ recognizer: SpeechRecognizer) {
        self.speechRecognizer = recognizer
        if session.isRunning {
            session.beginConfiguration()
            if let existingOutput = session.outputs.first(where: { $0 is AVCaptureAudioDataOutput }) {
                session.removeOutput(existingOutput)
            }
            if session.canAddOutput(audioDataOutput) {
                session.addOutput(audioDataOutput)
                audioDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "AudioDataOutputQueue"))
            }
            session.commitConfiguration()
        }
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try? audioSession.setActive(false)
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.allowBluetooth, .mixWithOthers])
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.005)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("🎤📱 Audio session setup failed: \(error)")
        }
    }

    func setupCamera() {
        session.beginConfiguration()
        setupAudioSession()
        
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get camera device")
            session.commitConfiguration()
            isReady = false
            return
        }
        currentCamera = device
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                print("Could not add video input")
                session.commitConfiguration()
                isReady = false
                return
            }
            
            if microphonePermissionGranted,
               let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            }
            
            videoOutput = AVCaptureMovieFileOutput()
            if let videoOutput = videoOutput {
                if session.canAddOutput(videoOutput) {
                    session.addOutput(videoOutput)
                }
            }
            
            if session.canAddOutput(audioDataOutput) {
                session.addOutput(audioDataOutput)
                audioDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "AudioDataOutputQueue"))
            }
            
            session.sessionPreset = .hd1920x1080
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
                DispatchQueue.main.async {
                    self?.isReady = true
                }
            }
        } catch {
            print("Camera setup failed: \(error)")
            session.commitConfiguration()
            isReady = false
        }
    }
    
    func toggleFlash(isOn: Bool) {
        guard let device = currentCamera, device.hasTorch else { return }
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
        isReady = false
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        
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
            }
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            }
            session.commitConfiguration()
            DispatchQueue.main.async {
                self.isReady = true
            }
        } catch {
            print("Error switching cameras: \(error.localizedDescription)")
            session.commitConfiguration()
            isReady = false
        }
    }
    
    func startRecording() {
        guard permissionGranted, let videoOutput = videoOutput else { return }
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent(generateFileName())
        currentVideoUrl = fileUrl
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            videoOutput.startRecording(to: fileUrl, recordingDelegate: self!)
            DispatchQueue.main.async {
                self?.isRecording = true
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
    
    func saveTake(fileName: String) {
        guard let videoUrl = currentVideoUrl else { return }
        guard FileManager.default.fileExists(at: videoUrl.path) else {
            print("Video file doesn't exist at path: \(videoUrl.path)")
            return
        }
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let destinationUrl = paths[0].appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(at: destinationUrl.path) {
                try FileManager.default.removeItem(at: destinationUrl)
            }
            try FileManager.default.moveItem(at: videoUrl, to: destinationUrl)
            currentVideoUrl = destinationUrl
        } catch {
            print("Error renaming video file: \(error.localizedDescription)")
        }
        
        DispatchQueue.main.async {
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.currentVideoUrl!)
                request?.creationDate = Date()
            } completionHandler: { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        print("Video saved successfully to gallery: \(fileName)")
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
    
    private func generateFileName() -> String {
        let fileFormat = settingsManager.settings.fileNameFormat
        if fileFormat.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            return "video_\(dateFormatter.string(from: Date())).mov"
        }
        return fileFormat + ".mov"
    }
}
//extension CameraManager: AVCaptureAudioDataOutputSampleBufferDelegate {
//    func captureOutput(_ output: AVCaptureOutput,
//                       didOutput sampleBuffer: CMSampleBuffer,
//                       from connection: AVCaptureConnection) {
//        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
//              CMFormatDescriptionGetMediaType(formatDesc) == kCMMediaType_Audio else {
//            return
//        }
//        speechRecognizer?.appendAudioSampleBuffer(sampleBuffer)
//    }
//}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        print("Started recording to: \(fileURL.path)")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        if let error = error {
            print("Error recording video: \(error.localizedDescription)")
            return
        }
        DispatchQueue.main.async {
            self.currentVideoUrl = outputFileURL
        }
    }
}
