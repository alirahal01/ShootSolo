import SwiftUI
import AVFoundation
import Photos
import Combine

struct CameraView: View {
    @StateObject private var viewModel: CameraViewModel
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authState: AuthState
    @State private var showCameraAlert = false
    @State private var showMicrophoneAlert = false
    @State private var lastSoundPlayTime = Date.distantPast
    
    // Combine cancellable
    @State private var stateCancellable: AnyCancellable?
    
    init() {
        _viewModel = StateObject(wrappedValue: CameraViewModel())
    }
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if viewModel.cameraManager.permissionGranted {
                // Camera Preview Container
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = width * 16/9 // 9:16 aspect ratio
                    
                    ZStack {
                        // Camera Preview
                        CameraPreviewView(session: viewModel.cameraManager.session)
                            .frame(width: width, height: height)
                            .clipped()
                        
                        // Grid Overlay - exactly matching preview dimensions
                        if viewModel.isGridEnabled {
                            GridOverlay()
                                .frame(width: width, height: height)
                                .clipped()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: 20) // Changed from 40 to 20 for toolbar spacing
                }
                
                // Controls overlay
                VStack {
                    Spacer()
                    
                    // Zoom Control
                    ZoomControlView(zoomFactor: $viewModel.zoomFactor)
                        .onChange(of: viewModel.zoomFactor) { newValue in
                            viewModel.setZoomFactor(newValue)
                        }
                        .padding(.bottom, 8) // 8pt padding between zoom and message HUD
                    
                    MessageHUDView(
                        speechRecognizer: viewModel.speechRecognizer,
                        context: .camera
                    )
                    .padding(.bottom, 12) // Reduced from 20 to 12 to bring controls closer
                    
                    // Bottom Controls
                    CameraBottomControls(
                        isRecording: $viewModel.isRecording,
                        currentTake: $viewModel.currentTake,
                        startRecording: {
                            Task {
                                await viewModel.startRecording()
                            }
                        },
                        stopRecording: {
                            Task {
                                await viewModel.stopRecording()
                            }
                        },
                        switchCamera: viewModel.cameraManager.switchCamera
                    )
                    .padding(.bottom, 40) // Reduced from 30 to 20 to push up
                }
                
                // Save Dialog
                if viewModel.showingSaveDialog {
                    SaveTakeDialog(
                        takeNumber: viewModel.currentTake,
                        onSave: {
                            print("📱 CameraView: Save action triggered")
                            viewModel.saveTake()
                        },
                        onDiscard: {
                            print("📱 CameraView: Discard action triggered")
                            viewModel.discardTake()
                        },
                        speechRecognizer: viewModel.speechRecognizer
                    )
                }
            } else {
                // Permission denied view
                VStack(spacing: 20) {
                    Image(systemName: getPermissionIcon())
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    
                    Text(permissionDeniedTitle)
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text(permissionDeniedMessage)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal)
                    
                    // Show buttons based on actual permission status
                    VStack(spacing: 15) {
                        if shouldShowCameraButton() {
                            Button("Check Camera") {
                                checkCameraPermission()
                            }
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        if shouldShowMicrophoneButton() {
                            Button("Check Microphone") {
                                checkMicrophonePermission()
                            }
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 15) {
                    if !viewModel.isRecording {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gear")
                                .foregroundColor(.white)
                        }
                    }
                    
                    Button(action: {
                        viewModel.isGridEnabled.toggle()
                    }) {
                        Image(systemName: viewModel.isGridEnabled ? "grid.circle.fill" : "grid.circle")
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        viewModel.toggleFlash()
                    }) {
                        Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if viewModel.isRecording {
                        Text(viewModel.timerText)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .fixedSize()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.red)
                            )
                            .foregroundColor(.white)
                        
                        Text("Take \(viewModel.currentTake)")
                            .foregroundColor(.white)
                    } else {
                        Button {
                            viewModel.showingCreditsView = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Credits: \(viewModel.creditCount)")
                                    .foregroundColor(.white)
                                Image(systemName: "plus.square.fill")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            print("📱 CameraView: View appeared")
            setupStateObserver()
            
            // Only restart speech recognition if it's not already initializing
            if !viewModel.speechRecognizer.isInitializing {
                viewModel.restartSpeechRecognition()
            } else {
                print("📱 CameraView: Speech recognizer is initializing, not restarting")
            }
            
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            print("📱 CameraView: View disappeared")
            stateCancellable?.cancel()
            viewModel.speechRecognizer.stopListening()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $viewModel.showingCreditsView) {
            CreditsView()
        }
        .alert("Session Expired", isPresented: $authState.showAuthAlert) {
            Button("Sign In", role: .destructive) {
                authState.isLoggedIn = false
            }
        } message: {
            Text("Your session has expired. Please sign in again to continue.")
        }
        .alert("Camera Access Required", isPresented: $showCameraAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                openSettings()
            }
        } message: {
            Text("Please enable camera access in Settings to use this feature")
        }
        .alert("Microphone Access Required", isPresented: $showMicrophoneAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                openSettings()
            }
        } message: {
            Text("Please enable microphone access in Settings to record videos with audio")
        }
        .onChange(of: scenePhase) { newPhase in
            print("📱 CameraView: Scene phase changed to \(newPhase)")
            
            switch newPhase {
            case .active:
                // App came to foreground
                print("📱 CameraView: App became active")
                
                // First notify speech recognizer about state change
                viewModel.speechRecognizer.handleAppStateChange(isBackground: false)
                
                // Then force restart speech recognition after a short delay
                // This ensures the audio session has time to activate properly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("📱 CameraView: Force restarting speech recognition after background")
                    viewModel.forceRestartSpeechRecognition()
                }
                
            case .inactive:
                // App is transitioning between states
                print("📱 CameraView: App became inactive")
                
            case .background:
                // App went to background
                print("📱 CameraView: App went to background")
                viewModel.speechRecognizer.handleAppStateChange(isBackground: true)
                
            @unknown default:
                break
            }
        }
    }
    
    private func setupStateObserver() {
        // Cancel existing subscription if any
        stateCancellable?.cancel()
        
        // Combine the publishers we want to observe
        stateCancellable = Publishers.CombineLatest3(
            viewModel.speechRecognizer.$isListening,
            viewModel.speechRecognizer.$hasError,
            viewModel.$showingSaveDialog
        )
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { isListening, hasError, wasShowingDialog in
            print("📱 State change - isListening: \(isListening), hasError: \(hasError), wasShowingDialog: \(wasShowingDialog)")
            
            if isListening && !hasError && !wasShowingDialog {
                let now = Date()
                // Still keep the time check as additional safety
                if now.timeIntervalSince(self.lastSoundPlayTime) >= 0.3 {
                    SoundManager.shared.playReadySound()
                    self.lastSoundPlayTime = now
                    print("📱 CameraView: Playing ready sound")
                }
            }
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            showCameraAlert = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if !granted {
                        showCameraAlert = true
                    }
                }
            }
        default:
            break
        }
    }
    
    private func checkMicrophonePermission() {
        if !viewModel.cameraManager.microphonePermissionGranted {
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .denied, .restricted:
                showMicrophoneAlert = true
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async {
                        if !granted {
                            self.showMicrophoneAlert = true
                        } else {
                            // Reinitialize camera setup if needed
                            self.viewModel.cameraManager.setupCamera()
                        }
                    }
                }
            default:
                break
            }
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // Add these computed properties to CameraView
    private var permissionDeniedTitle: String {
        if !viewModel.cameraManager.permissionGranted && !viewModel.cameraManager.microphonePermissionGranted {
            return "Camera & Microphone Access Required"
        } else if !viewModel.cameraManager.permissionGranted {
            return "Camera Access Required"
        } else {
            return "Microphone Access Required"
        }
    }
    
    private var permissionDeniedMessage: String {
        if !viewModel.cameraManager.permissionGranted && !viewModel.cameraManager.microphonePermissionGranted {
            return "Please enable both camera and microphone access in Settings to use this feature"
        } else if !viewModel.cameraManager.permissionGranted {
            return "Please enable camera access in Settings to use this feature"
        } else {
            return "Please enable microphone access in Settings to record videos with audio"
        }
    }
    
    // Add these helper functions
    private func getPermissionIcon() -> String {
        if shouldShowCameraButton() {
            return "camera.slash.fill"
        } else if shouldShowMicrophoneButton() {
            return "mic.slash.fill"
        }
        return "camera.slash.fill" // Default icon
    }
    
    private func shouldShowCameraButton() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }
    
    private func shouldShowMicrophoneButton() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }
}
