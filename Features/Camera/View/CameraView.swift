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
    @State private var stateCancellable: AnyCancellable?
    @State private var isModalPresented = false
    @State private var isSystemUIPresented = false
    @State private var isNetworkAlertVisible = false
    @State private var systemUICooldownActive = false
    @State private var currentPermissionCheck: PermissionType?

    enum PermissionType {
        case camera, microphone, speechRecognition, photoLibrary
    }
    
    init() {
        _viewModel = StateObject(wrappedValue: CameraViewModel())
    }
    
    var body: some View {
        mainContent
            .toolbar { toolbarContent }
            .onAppear(perform: handleAppear)
            .onDisappear(perform: handleDisappear)
            .sheet(isPresented: $viewModel.showingCreditsView) {
                CreditsView()
                    .withNetworkStatusOverlay()
                    .trackModalPresentation(isPresented: $isModalPresented)
            }
            .alert("Camera Access Required", isPresented: $showCameraAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") { openSettings() }
            } message: {
                Text("Please enable camera access in Settings to use this feature")
            }
            .alert("Microphone Access Required", isPresented: $showMicrophoneAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") { openSettings() }
            } message: {
                Text("Please enable microphone access in Settings to record videos with audio")
            }
            .alert("Speech Recognition Required", isPresented: $showSpeechRecognitionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") { openSettings() }
            } message: {
                Text("Please enable speech recognition in Settings to use voice commands")
            }
            .alert("Photo Library Access Required", isPresented: $showPhotoLibraryAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") { openSettings() }
            } message: {
                Text("Please enable photo library access in Settings to save your videos")
            }
            .alert("Session Expired", isPresented: $authState.showAuthAlert) {
                Button("Sign In", role: .destructive) {
                    authState.isLoggedIn = false
                }
            } message: {
                Text("Your session has expired. Please sign in again to continue.")
            }
            .onChange(of: scenePhase, perform: handleScenePhaseChange)
            .onReceive(NetworkMonitor.shared.$isConnected) { isConnected in
                isNetworkAlertVisible = !isConnected
            }
    }
    
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
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = width * 16/9
                ZStack {
                    CameraPreviewView(session: viewModel.cameraManager.session)
                        .frame(width: width, height: height)
                        .clipped()
                    
                    if viewModel.isGridEnabled {
                        GridOverlay()
                            .frame(width: width, height: height)
                            .clipped()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: 20)
            }
            
            if !viewModel.showingSaveDialog {
                cameraControlsOverlay
            } else {
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
                    .padding(.bottom, 100)
                }
            }
        }
    }
    
    private var cameraControlsOverlay: some View {
        VStack {
            Spacer()
            ZoomControlView(zoomFactor: $viewModel.zoomFactor)
                .onChange(of: viewModel.zoomFactor) { newValue in
                    viewModel.setZoomFactor(newValue)
                }
                .padding(.bottom, 8)
            
            MessageHUDView(speechRecognizer: viewModel.speechRecognizer, context: .camera)
                .padding(.bottom, 12)
            
            CameraBottomControls(
                isRecording: $viewModel.isRecording,
                currentTake: $viewModel.currentTake,
                startRecording: {
                    Task { await viewModel.startRecording() }
                },
                stopRecording: {
                    Task { await viewModel.stopRecording() }
                },
                switchCamera: viewModel.cameraManager.switchCamera
            )
            .padding(.bottom, 40)
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
            permissionButtons
        }
        .padding()
    }
    
    private var permissionButtons: some View {
        VStack(spacing: 15) {
            if shouldShowCameraButton() {
                Button("Enable Camera") { openSettings() }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            if shouldShowMicrophoneButton() {
                Button("Enable Microphone") { openSettings() }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            if shouldShowSpeechRecognitionButton() {
                Button("Enable Speech Recognition") { openSettings() }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            if shouldShowPhotoLibraryButton() {
                Button("Enable Photo Library Access") { openSettings() }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 15) {
                if !viewModel.isRecording {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                            .foregroundColor(.white)
                    }
                }
                Button { viewModel.isGridEnabled.toggle() } label: {
                    Image(systemName: viewModel.isGridEnabled ? "grid.circle.fill" : "grid.circle")
                        .foregroundColor(.white)
                }
                Button { viewModel.toggleFlash() } label: {
                    Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .foregroundColor(.white)
                }
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                if viewModel.isRecording {
                    HStack {
                        Text(viewModel.timerText)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .fixedSize()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.red))
                            .foregroundColor(.white)
                        Text("Take \(viewModel.currentTake)")
                            .foregroundColor(.white)
                    }
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
    
    // MARK: - Lifecycle
    
    private func handleAppear() {
        print("📱 CameraView: View appeared")
        checkAllPermissions()
        setupNotificationObservers()
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
        switch newPhase {
        case .active:
            print("📱 CameraView: became active")
            systemUICooldownActive = true
            viewModel.speechRecognizer.handleAppStateChange(isBackground: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.viewModel.forceRestartSpeechRecognition()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.systemUICooldownActive = false
                }
            }
        case .inactive:
            print("📱 CameraView: became inactive")
        case .background:
            print("📱 CameraView: went to background")
            viewModel.speechRecognizer.handleAppStateChange(isBackground: true)
        @unknown default:
            break
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil, queue: .main) { _ in
            self.isSystemUIPresented = true
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                               object: nil, queue: .main) { _ in
            self.isSystemUIPresented = true
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil, queue: .main) { _ in
            self.systemUICooldownActive = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isSystemUIPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.systemUICooldownActive = false
                }
            }
        }
        NotificationCenter.default.addObserver(forName: UIScene.willDeactivateNotification,
                                               object: nil, queue: .main) { _ in
            self.isSystemUIPresented = true
        }
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIScene.willDeactivateNotification, object: nil)
    }
    
    // MARK: - Permission Checks
    
    private func checkAllPermissions() {
        checkCameraPermission()
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            checkMicrophonePermission()
        case .denied, .restricted:
            showCameraAlert = true
            currentPermissionCheck = .camera
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
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
            checkPhotoLibraryPermission()
        case .denied, .restricted:
            showMicrophoneAlert = true
            currentPermissionCheck = .microphone
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted {
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
            checkSpeechRecognitionPermission()
        case .denied, .restricted:
            showPhotoLibraryAlert = true
            currentPermissionCheck = .photoLibrary
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
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
            initializeAfterPermissionsGranted()
        case .denied, .restricted:
            showSpeechRecognitionAlert = true
            currentPermissionCheck = .speechRecognition
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized {
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
        viewModel.cameraManager.setupCamera()
        setupStateObserver()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !self.viewModel.speechRecognizer.isInitializing {
                self.viewModel.forceRestartSpeechRecognition()
            }
        }
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    private func setupStateObserver() {
        stateCancellable?.cancel()
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
            let (isListening, hasError) = combined
            if shouldPlaySound && cameraReady && isListening && !hasError {
                // Play "ready" sound
                SoundManager.shared.playReadySound()
                self.lastSoundPlayTime = Date()
                print("📱 CameraView: Playing ready sound")
                self.viewModel.readySoundWasPlayed()
            }
        }
    }
    
    private func areAllPermissionsGranted() -> Bool {
        let camera = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        let mic = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let speech = SFSpeechRecognizer.authorizationStatus() == .authorized
        let photos = PHPhotoLibrary.authorizationStatus() == .authorized ||
                     PHPhotoLibrary.authorizationStatus() == .limited
        return camera && mic && speech && photos
    }
    
    // MARK: - Permission Helpers
    
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
            return "exclamationmark.triangle.fill"
        }
    }
    
    private func shouldShowCameraButton() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return status == .denied || status == .restricted
    }
    
    private func shouldShowMicrophoneButton() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .denied || status == .restricted
    }
    
    private func shouldShowSpeechRecognitionButton() -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        return status == .denied || status == .restricted
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
}
