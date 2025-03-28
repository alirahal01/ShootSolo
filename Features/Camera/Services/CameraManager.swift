import AVFoundation
import Photos

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isRecording = false
    @Published var permissionGranted = false
    @Published var isReady = false
    
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentCamera: AVCaptureDevice?
    private var currentPosition: AVCaptureDevice.Position = .back
    private var currentVideoUrl: URL?
    
    private let settingsManager = SettingsManager.shared
    
    private var supportedZoomFactors: [CGFloat] = []
    
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
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, 
                                      mode: .videoRecording,
                                      options: [.allowBluetooth, .mixWithOthers, .defaultToSpeaker])
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.005)
            try audioSession.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    private func setupCamera() {
        setupAudioSession()
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get camera device")
            isReady = false
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
                isReady = false
                return
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
                isReady = false
                return
            }
            
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
                DispatchQueue.main.async {
                    self?.isReady = true
                }
            }
        } catch {
            print("Failed to setup camera: \(error.localizedDescription)")
            session.commitConfiguration()
            isReady = false
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
        
        isReady = false
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
            DispatchQueue.main.async {
                self.isReady = true
            }
            
        } catch {
            print("Error switching cameras: \(error.localizedDescription)")
            session.commitConfiguration()
            isReady = false
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
    
    private func configureVideoConnection() {
        guard let videoConnection = videoOutput?.connection(with: .video),
              let device = currentCamera else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // Get the device zoom factor
            let currentZoom = device.videoZoomFactor
            
            // Get the maximum scale and crop factor for the connection
            let maxScaleAndCrop = videoConnection.videoMaxScaleAndCropFactor
            
            // Calculate the normalized scale factor (0.0 to 1.0)
            let normalizedScale = (currentZoom - 1.0) / (device.activeFormat.videoMaxZoomFactor - 1.0)
            
            // Map the normalized scale to the connection's valid range
            let connectionScale = 1.0 + (normalizedScale * (maxScaleAndCrop - 1.0))
            
            // Clamp the scale factor to valid range
            let clampedScale = min(connectionScale, maxScaleAndCrop)
            
            // Apply the scale factor to the connection
            videoConnection.videoScaleAndCropFactor = clampedScale
            
            // Enable video stabilization if available
            if videoConnection.isVideoStabilizationSupported {
                videoConnection.preferredVideoStabilizationMode = .auto
            }
            
            device.unlockForConfiguration()
            
            print("Video connection configured - device zoom: \(currentZoom), connection scale: \(clampedScale)")
        } catch {
            print("Failed to configure video connection: \(error)")
        }
    }
    
    func startRecording() {
        guard permissionGranted else { return }
        guard let videoOutput = videoOutput else {
            print("Video output not available")
            return
        }
        
        // Important: Configure video connection before each recording
        configureVideoConnection()
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent(generateFileName())
        currentVideoUrl = fileUrl
        
        // Start recording on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            videoOutput.startRecording(to: fileUrl, recordingDelegate: self!)
            
            DispatchQueue.main.async {
                self?.isRecording = true
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop recording immediately
        videoOutput?.stopRecording()
        
        // Update recording state
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    func saveTake(fileName: String) {
        guard let videoUrl = currentVideoUrl else {
            print("No video URL available")
            return
        }
        
        guard FileManager.default.fileExists(at: videoUrl.path) else {
            print("Video file doesn't exist at path: \(videoUrl.path)")
            return
        }
        
        // Create a new URL with the provided fileName
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let destinationUrl = paths[0].appendingPathComponent(fileName)
        
        // First, try to move the file to the new location with the proper name
        do {
            if FileManager.default.fileExists(at: destinationUrl.path) {
                try FileManager.default.removeItem(at: destinationUrl)
            }
            try FileManager.default.moveItem(at: videoUrl, to: destinationUrl)
            currentVideoUrl = destinationUrl
        } catch {
            print("Error renaming video file: \(error.localizedDescription)")
            // If rename fails, continue with original file
        }
        
        // Save to photo library
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
    
    private func updateSupportedZoomFactors() {
        guard let device = currentCamera else {
            print("No camera device available for zoom factors")
            return
        }
        
        print("Updating zoom factors for device type: \(device.deviceType)")
        
        // Check if device supports ultra wide
        if device.deviceType == .builtInUltraWideCamera {
            // True ultra-wide camera available
            supportedZoomFactors = [0.5, 1.0, 2.0]
            print("Ultra wide camera detected, zoom factors: \(supportedZoomFactors)")
        } else {
            // For regular wide angle camera
            let maxZoom = device.activeFormat.videoMaxZoomFactor
            print("Regular camera detected, max zoom: \(maxZoom)")
            
            // Instead of trying to zoom out (which might not work),
            // we'll use 1.0 as our widest view and zoom in for other options
            supportedZoomFactors = [1.0, 1.5, 2.0]
            print("Setting standard zoom factors: \(supportedZoomFactors)")
        }
        
        // Ensure current zoom factor is valid
        if let currentZoom = supportedZoomFactors.first {
            setZoomFactor(currentZoom)
            print("Set initial zoom factor to: \(currentZoom)")
        }
    }
    
    func setZoomFactor(_ zoomFactor: CGFloat) {
        guard let device = currentCamera,
              let videoConnection = videoOutput?.connection(with: .video) else {
            print("Camera device or video connection not available")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // Get device zoom range
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = device.maxAvailableVideoZoomFactor
            
            // Calculate the actual zoom factor to apply
            var actualZoom = zoomFactor
            
            // Ensure 1.0 is actually 1.0 (no zoom)
            switch zoomFactor {
            case 0.5:
                // For ultra-wide, use minimum zoom
                actualZoom = device.deviceType == .builtInUltraWideCamera ? 0.5 : minZoom
            case 1.0:
                // Always use exactly 1.0 for no zoom
                actualZoom = 1.0
            case 2.0:
                // Use 2x or max available zoom
                actualZoom = min(2.0, maxZoom)
            default:
                break
            }
            
            // Clamp zoom within device limits
            let clampedZoom = max(minZoom, min(actualZoom, maxZoom))
            
            // Set device zoom
            device.videoZoomFactor = clampedZoom
            
            // Calculate and set connection scale factor
            let maxScaleAndCrop = videoConnection.videoMaxScaleAndCropFactor
            
            // Ensure scale factor is proportional to zoom, with 1.0 being no scale
            let normalizedScale = (clampedZoom - 1.0) / (maxZoom - 1.0)
            let connectionScale = 1.0 + (normalizedScale * (maxScaleAndCrop - 1.0))
            let clampedScale = min(connectionScale, maxScaleAndCrop)
            
            videoConnection.videoScaleAndCropFactor = clampedScale
            
            print("Zoom updated - requested: \(zoomFactor), actual zoom: \(clampedZoom), scale: \(clampedScale)")
            device.unlockForConfiguration()
            
        } catch {
            print("Failed to set zoom factor: \(error)")
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
