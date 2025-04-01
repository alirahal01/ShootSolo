import SwiftUI
import AVFoundation
import Photos
import Combine
import Speech

struct CameraView: View {
    @StateObject private var viewModel: CameraViewModel
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authState: AuthState
    @State private var showCameraAlert = false
    @State private var showMicrophoneAlert = false
    @State private var showSpeechRecognitionAlert = false
    @State private var showPhotoLibraryAlert = false
    @State private var lastSoundPlayTime = Date.distantPast
    
    // Combine cancellable
    @State private var stateCancellable: AnyCancellable?
    
    // Track when modals are presented
    @State private var isModalPresented = false
    
    // Track when system UI is shown (notification center, control center)
    @State private var isSystemUIPresented = false
    
    // Track when network alert is visible
    @State private var isNetworkAlertVisible = false
    
    // Add this property to track when we've just returned from system UI
    @State private var systemUICooldownActive = false
    
    // Track which permission screen to show
    @State private var currentPermissionCheck: PermissionType?
    
    // Define permission types
    enum PermissionType {
        case camera
        case microphone
        case speechRecognition
        case photoLibrary
    }
    
    init() {
        _viewModel = StateObject(wrappedValue: CameraViewModel())
    }
    
    var body: some View {
        // Extract main content to improve readability
        mainContent
            .toolbar { toolbarContent }
            .onAppear(perform: handleAppear)
            .onDisappear(perform: handleDisappear)
            .sheet(isPresented: $viewModel.showingCreditsView) {
                CreditsView()
                    .withNetworkStatusOverlay()
                    .trackModalPresentation(isPresented: $isModalPresented)
            }
            // Permission alerts
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
            .alert("Speech Recognition Required", isPresented: $showSpeechRecognitionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    openSettings()
                }
            } message: {
                Text("Please enable speech recognition in Settings to use voice commands")
            }
            .alert("Photo Library Access Required", isPresented: $showPhotoLibraryAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    openSettings()
                }
            } message: {
                Text("Please enable photo library access in Settings to save your videos")
            }
            // Alerts
            .alert("Session Expired", isPresented: $authState.showAuthAlert) {
                Button("Sign In", role: .destructive) {
                    authState.isLoggedIn = false
                }
            } message: {
                Text("Your session has expired. Please sign in again to continue.")
            }
            .onChange(of: scenePhase, perform: handleScenePhaseChange)
            .onReceive(NetworkMonitor.shared.$isConnected) { isConnected in
                // Track when network alert is visible
                isNetworkAlertVisible = !isConnected
            }
    }
    
    // MARK: - View Components
    
    private var mainContent: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if !areAllPermissionsGranted() {
                permissionDeniedContent
            } else {
                cameraPreviewContent
            }
        }
    }
    
    private var cameraPreviewContent: some View {
        ZStack {
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
            
            // Controls overlay - only show when save dialog is not visible
            if !viewModel.showingSaveDialog {
                cameraControlsOverlay
            } else {
                // Save Dialog - centered in the same position as controls
                VStack {
                    Spacer()
                    
                    SaveTakeDialog(
                        takeNumber: viewModel.currentTake,
                        onSave: {
                            viewModel.saveTake()
                            viewModel.showingSaveDialog = false
                            viewModel.handleSaveDialogDismissed()
                        },
                        onDiscard: {
                            viewModel.discardTake()
                            viewModel.showingSaveDialog = false
                            viewModel.handleSaveDialogDismissed()
                        },
                        speechRecognizer: viewModel.speechRecognizer
                    )
                    .padding(.bottom, 100) // Position it above where the controls would be
                }
            }
        }
    }
    
    private var cameraControlsOverlay: some View {
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
    }
    
    private var permissionDeniedContent: some View {
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
            permissionButtons
        }
        .padding()
    }
    
    private var permissionButtons: some View {
        VStack(spacing: 15) {
            if shouldShowCameraButton() {
                Button("Enable Camera") {
                    openSettings()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            if shouldShowMicrophoneButton() {
                Button("Enable Microphone") {
                    openSettings()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            if shouldShowSpeechRecognitionButton() {
                Button("Enable Speech Recognition") {
                    openSettings()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            if shouldShowPhotoLibraryButton() {
                Button("Enable Photo Library Access") {
                    openSettings()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            leadingToolbarItems
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            trailingToolbarItems
        }
    }
    
    private var leadingToolbarItems: some View {
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
    
    private var trailingToolbarItems: some View {
        HStack {
            if viewModel.isRecording {
                recordingIndicator
            } else {
                creditsButton
            }
        }
    }
    
    private var recordingIndicator: some View {
        HStack {
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
        }
    }
    
    private var creditsButton: some View {
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
    
    // MARK: - Lifecycle Methods
    
    private func handleAppear() {
        print("📱 CameraView: View appeared")
        
        // First check all permissions
        checkAllPermissions()
        
        // Only set up observers - actual initialization will happen after permissions
        setupNotificationObservers()
        
        // Reset flags
        isModalPresented = false
        isSystemUIPresented = false
        isNetworkAlertVisible = false
        systemUICooldownActive = false
    }
    
    private func handleDisappear() {
        print("📱 CameraView: View disappeared")
        stateCancellable?.cancel()
        removeNotificationObservers()
        viewModel.speechRecognizer.stopListening()
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    private func handleScenePhaseChange(newPhase: ScenePhase) {
        print("📱 CameraView: Scene phase changed to \(newPhase)")
        
        switch newPhase {
        case .active:
            handleActiveScenePhase()
        case .inactive:
            print("📱 CameraView: App became inactive")
        case .background:
            print("📱 CameraView: App went to background")
            viewModel.speechRecognizer.handleAppStateChange(isBackground: true)
        @unknown default:
            break
        }
    }
    
    private func handleActiveScenePhase() {
        // App came to foreground
        print("📱 CameraView: App became active")
        
        // Set cooldown flag to prevent sound
        systemUICooldownActive = true
        
        // First notify speech recognizer about state change
        viewModel.speechRecognizer.handleAppStateChange(isBackground: false)
        
        // Then force restart speech recognition after a short delay
        // This ensures the audio session has time to activate properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("📱 CameraView: Force restarting speech recognition after background")
            
            // Temporarily disable sound playback during restart
            let previousShouldPlayValue = self.viewModel.shouldPlayReadySound
            self.viewModel.shouldPlayReadySound = false
            
            // Restart speech recognition
            self.viewModel.forceRestartSpeechRecognition()
            
            // Restore the original value after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.viewModel.shouldPlayReadySound = previousShouldPlayValue
                
                // Reset cooldown after a longer delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.systemUICooldownActive = false
                }
            }
        }
    }
    
    // MARK: - Observer Setup
    
    private func setupStateObserver() {
        // Cancel existing subscription if any
        stateCancellable?.cancel()
        
        // Create a more readable and maintainable state observer
        let speechState = Publishers.CombineLatest(
            viewModel.speechRecognizer.$isListening,
            viewModel.speechRecognizer.$hasError
        )
        
        stateCancellable = Publishers.CombineLatest3(
            speechState,
            viewModel.cameraManager.$isReady,
            viewModel.$shouldPlayReadySound
        )
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { combined, cameraReady, shouldPlaySound in
            
            // Destructure the first combined tuple
            let (isListening, hasError) = combined
            
            print("📱 State change - listening: \(isListening), error: \(hasError), cameraReady: \(cameraReady), shouldPlay: \(shouldPlaySound)")
            
            // Check if we should play the ready sound
            self.checkAndPlayReadySound(
                isListening: isListening,
                hasError: hasError,
                cameraReady: cameraReady,
                shouldPlaySound: shouldPlaySound
            )
        }
    }
    
    private func checkAndPlayReadySound(
        isListening: Bool,
        hasError: Bool,
        cameraReady: Bool,
        shouldPlaySound: Bool
    ) {
        if shouldPlayReadySound(
            isListening: isListening,
            hasError: hasError,
            cameraReady: cameraReady,
            shouldPlaySound: shouldPlaySound
        ) {
            SoundManager.shared.playReadySound()
            self.lastSoundPlayTime = Date()
            print("📱 CameraView: Playing ready sound")
            
            // Reset the flag after playing
            self.viewModel.readySoundWasPlayed()
        }
    }
    
    private func setupNotificationObservers() {
        // Observe when ANY system UI overlay appears
        // This covers:
        // - Notification Center
        // - Control Center
        // - Spotlight Search
        
        // When app resigns active (any system UI appears)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 CameraView: System UI appeared (willResignActive)")
            isSystemUIPresented = true
        }
        
        // When app becomes inactive (transition state)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 CameraView: App entered background")
            isSystemUIPresented = true
        }
        
        // When app becomes active again (system UI dismissed)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 CameraView: System UI dismissed (didBecomeActive)")
            
            // Set the cooldown flag
            self.systemUICooldownActive = true
            
            // Reset system UI flag after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isSystemUIPresented = false
                
                // Keep cooldown active for longer to prevent sound
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.systemUICooldownActive = false
                }
            }
        }
        
        // Additional notification for window scene phase changes
        // This helps catch some edge cases
        NotificationCenter.default.addObserver(
            forName: UIScene.willDeactivateNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 CameraView: Scene will deactivate")
            isSystemUIPresented = true
        }
    }
    
    private func removeNotificationObservers() {
        // Remove all observers when view disappears
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: UIScene.willDeactivateNotification,
            object: nil
        )
    }
    
    // MARK: - Permission Checking
    
    private func checkAllPermissions() {
        // Start with camera permission since it's the most fundamental for this app
        checkCameraPermission()
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Camera permission granted, move to microphone
            checkMicrophonePermission()
        case .denied, .restricted:
            showCameraAlert = true
            currentPermissionCheck = .camera
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        // Move to next permission check
                        self.checkMicrophonePermission()
                    } else {
                        self.showCameraAlert = true
                        self.currentPermissionCheck = .camera
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func checkMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            // Microphone permission granted, check photo library next
            // (Speech recognition depends on microphone, so check photo library first)
            checkPhotoLibraryPermission()
        case .denied, .restricted:
            showMicrophoneAlert = true
            currentPermissionCheck = .microphone
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted {
                        // Move to next permission check
                        self.checkPhotoLibraryPermission()
                    } else {
                        self.showMicrophoneAlert = true
                        self.currentPermissionCheck = .microphone
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            // Photo library permission granted, check speech recognition last
            // (Speech recognition is the most complex and depends on microphone)
            checkSpeechRecognitionPermission()
        case .denied, .restricted:
            showPhotoLibraryAlert = true
            currentPermissionCheck = .photoLibrary
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        // Move to next permission check
                        self.checkSpeechRecognitionPermission()
                    } else {
                        self.showPhotoLibraryAlert = true
                        self.currentPermissionCheck = .photoLibrary
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func checkSpeechRecognitionPermission() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            // All permissions granted, now initialize systems
            initializeAfterPermissionsGranted()
        case .denied, .restricted:
            showSpeechRecognitionAlert = true
            currentPermissionCheck = .speechRecognition
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        // All permissions granted, now initialize systems
                        self.initializeAfterPermissionsGranted()
                    } else {
                        self.showSpeechRecognitionAlert = true
                        self.currentPermissionCheck = .speechRecognition
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func initializeAfterPermissionsGranted() {
        print("📱 CameraView: All permissions granted, initializing systems")
        
        // First initialize camera
        viewModel.cameraManager.setupCamera()
        
        // Then set up state observer
        setupStateObserver()
        
        // Finally initialize speech recognition after a short delay
        // This ensures audio session conflicts are minimized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !self.viewModel.speechRecognizer.isInitializing {
                self.viewModel.restartSpeechRecognition()
            }
        }
        
        // Disable idle timer
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    private func areAllPermissionsGranted() -> Bool {
        let cameraPermission = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        let microphonePermission = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let speechPermission = SFSpeechRecognizer.authorizationStatus() == .authorized
        let photoLibraryPermission = PHPhotoLibrary.authorizationStatus() == .authorized || 
                                    PHPhotoLibrary.authorizationStatus() == .limited
        
        return cameraPermission && microphonePermission && speechPermission && photoLibraryPermission
    }
    
    // MARK: - Permission Helper Methods
    
    private var permissionDeniedTitle: String {
        switch currentPermissionCheck {
        case .camera:
            return "Camera Access Required"
        case .microphone:
            return "Microphone Access Required"
        case .speechRecognition:
            return "Speech Recognition Required"
        case .photoLibrary:
            return "Photo Library Access Required"
        case nil:
            // If multiple permissions are missing, show a general message
            return "Permissions Required"
        }
    }
    
    private var permissionDeniedMessage: String {
        switch currentPermissionCheck {
        case .camera:
            return "Please enable camera access in Settings to use this feature"
        case .microphone:
            return "Please enable microphone access in Settings to record videos with audio"
        case .speechRecognition:
            return "Please enable speech recognition in Settings to use voice commands"
        case .photoLibrary:
            return "Please enable photo library access in Settings to save your videos"
        case nil:
            // If multiple permissions are missing, show a general message
            return "Please enable all required permissions in Settings to use this app"
        }
    }
    
    private func getPermissionIcon() -> String {
        switch currentPermissionCheck {
        case .camera:
            return "camera.slash.fill"
        case .microphone:
            return "mic.slash.fill"
        case .speechRecognition:
            return "waveform.slash"
        case .photoLibrary:
            return "photo.slash.fill"
        case nil:
            // Default icon if no specific permission is being checked
            return "exclamationmark.triangle.fill"
        }
    }
    
    private func shouldShowCameraButton() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .denied || 
               AVCaptureDevice.authorizationStatus(for: .video) == .restricted
    }
    
    private func shouldShowMicrophoneButton() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .denied || 
               AVCaptureDevice.authorizationStatus(for: .audio) == .restricted
    }
    
    private func shouldShowSpeechRecognitionButton() -> Bool {
        return SFSpeechRecognizer.authorizationStatus() == .denied || 
               SFSpeechRecognizer.authorizationStatus() == .restricted
    }
    
    private func shouldShowPhotoLibraryButton() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus()
        return status == .denied || status == .restricted
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Sound Playback Logic
    
    private func shouldPlayReadySound(
        isListening: Bool,
        hasError: Bool,
        cameraReady: Bool,
        shouldPlaySound: Bool
    ) -> Bool {
        // Don't play sound if any UI elements are showing or during cooldown
        if isUIElementVisible() || systemUICooldownActive {
            return false
        }
        
        // Don't play if time conditions aren't met
        if !isTimingAppropriate() {
            return false
        }
        
        // Don't play if permissions aren't granted
        if !areAllPermissionsGranted() {
            return false
        }
        
        // Don't play if speech recognizer isn't ready
        if !isSpeechRecognizerReady(isListening: isListening, hasError: hasError) {
            return false
        }
        
        // All conditions are met
        return cameraReady && shouldPlaySound
    }
    
    private func isUIElementVisible() -> Bool {
        return isModalPresented || isSystemUIPresented || isNetworkAlertVisible
    }
    
    private func isTimingAppropriate() -> Bool {
        let now = Date()
        return now.timeIntervalSince(lastSoundPlayTime) >= 0.3
    }
    
    private func isSpeechRecognizerReady(isListening: Bool, hasError: Bool) -> Bool {
        return isListening && !hasError && !viewModel.speechRecognizer.isInitializing
    }
}
