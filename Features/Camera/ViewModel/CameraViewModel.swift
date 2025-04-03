import Foundation
import Combine
import AVFoundation
import SwiftUI
import Photos

@MainActor
class CameraViewModel: ObservableObject {
    enum RecordingState {
        case idle, starting, recording, stopping, savingDialog
        var canStart: Bool { self == .idle }
        var canStop: Bool { self == .recording }
    }
    
    @Published var isRecording = false
    @Published var isGridEnabled = false
    @Published var isFlashOn = false
    @Published var currentTake = 1
    @Published var zoomFactor: CGFloat = 1.0
    @Published var recordingTime: Int = 0
    @Published var showingSaveDialog = false
    @Published var timerText: String = "00:00"
    @Published var creditCount: Int = 0
    @Published var showingCreditsView = false
    @Published private(set) var isInitialized = false
    
    var cameraManager: CameraManager
    var speechRecognizer: SpeechRecognizer
    
    private var recordingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var recordingState: RecordingState = .idle {
        didSet { isRecording = (recordingState == .recording) }
    }
    
    // Controls if we play "Ready" sound
    @Published var shouldPlayReadySound = false
    
    init(cameraManager: CameraManager = CameraManager()) {
        self.cameraManager = cameraManager
        self.speechRecognizer = SpeechRecognizer()
        cameraManager.setSpeechRecognizer(speechRecognizer)
        
        // Observe credits
        CreditsManager.shared.$creditsBalance
            .receive(on: RunLoop.main)
            .assign(to: &$creditCount)
        
        // Handle voice commands
        speechRecognizer.onCommandDetected = { [weak self] command in
            Task { [weak self] in
                guard let self = self else { return }
                switch command {
                case "start":
                    if self.recordingState.canStart {
                        await self.startRecording()
                    }
                case "stop":
                    if self.recordingState.canStop {
                        await self.stopRecording()
                    }
                case "yes":
                    if case .savingDialog = self.recordingState {
                        self.saveTake()
                    }
                case "no":
                    if case .savingDialog = self.recordingState {
                        self.discardTake()
                    }
                default:
                    break
                }
                self.forceRestartSpeechRecognition()
            }
        }
        
        Task { @MainActor in
            await self.initialize()
        }
    }
    
    private func initialize() async {
        // Attempt to load an ad, etc. if needed
        try? await Task.sleep(for: .seconds(0.5))
        
        // Attempt to auto-start recognition if not in error
        if !speechRecognizer.isListening,
           !speechRecognizer.isInitializing,
           !speechRecognizer.hasError {
            speechRecognizer.startListening(context: .camera)
        }
        isInitialized = true
    }
    
    // Mark: - Start/Stop Recording
    
    func startRecording() async {
        guard recordingState.canStart else { return }
        recordingState = .starting
        
        if await CreditsManager.shared.useCredit() {
            let soundDuration = SoundManager.shared.getStartSoundDuration()
            SoundManager.shared.playStartSound()
            try? await Task.sleep(for: .seconds(soundDuration))
            
            cameraManager.startRecording()
            startTimer()
            recordingState = .recording
        } else {
            recordingState = .idle
            showingCreditsView = true
        }
    }
    
    func stopRecording() async {
        guard recordingState.canStop else { return }
        recordingState = .stopping
        
        cameraManager.stopRecording()
        stopTimer()
        
        let stopSoundDuration = SoundManager.shared.getStopSoundDuration()
        SoundManager.shared.playStopSound()
        try? await Task.sleep(for: .seconds(stopSoundDuration))
        
        speechRecognizer.stopListening()
        try? await Task.sleep(for: .seconds(0.3))
        
        recordingState = .savingDialog
        showingSaveDialog = true
        speechRecognizer.startListening(context: .saveDialog)
    }
    
    func saveTake() {
        guard case .savingDialog = recordingState else { return }
        cameraManager.saveTake(fileName: currentFileName)
        currentTake += 1
        speechRecognizer.stopListening()
        showingSaveDialog = false
        
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            recordingState = .idle
            shouldPlayReadySound = true
            forceRestartSpeechRecognition()
        }
    }
    
    func discardTake() {
        guard case .savingDialog = recordingState else { return }
        cameraManager.discardTake()
        speechRecognizer.stopListening()
        showingSaveDialog = false
        
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            recordingState = .idle
            shouldPlayReadySound = true
            forceRestartSpeechRecognition()
        }
    }
    
    private var currentFileName: String {
        FileNameGenerator.generateVideoFileName(takeNumber: currentTake)
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        recordingTime = 0
        updateTimerText()
        stopTimer(resetText: false)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.isRecording {
                    self.recordingTime += 1
                    self.updateTimerText()
                } else {
                    self.stopTimer()
                }
            }
            if let timer = self.recordingTimer {
                timer.tolerance = 0.1
                RunLoop.current.add(timer, forMode: .common)
            }
        }
    }
    
    private func stopTimer(resetText: Bool = true) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            if resetText {
                self.recordingTime = 0
                self.updateTimerText()
            }
        }
    }
    
    private func updateTimerText() {
        guard recordingTime >= 0 else {
            timerText = "00:00:00"
            return
        }
        let hours = Int(recordingTime / 3600)
        let minutes = Int((recordingTime % 3600) / 60)
        let seconds = Int(recordingTime % 60)
        if hours > 0 {
            timerText = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            timerText = String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Flash, Camera, Zoom
    
    func toggleFlash() {
        isFlashOn.toggle()
        cameraManager.toggleFlash(isOn: isFlashOn)
    }
    
    func switchCamera() {
        cameraManager.switchCamera()
    }
    
    func setZoomFactor(_ factor: CGFloat) {
        zoomFactor = factor
        cameraManager.setZoomFactor(factor)
    }
    
    // MARK: - Forced Speech Recognition Restart
    func forceRestartSpeechRecognition() {
        // STOP
        speechRecognizer.stopListening()
        
        // After short delay, START
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !self.speechRecognizer.hasError,
               !self.speechRecognizer.isInitializing {
                let context: CommandContext = self.showingSaveDialog ? .saveDialog : .camera
                self.speechRecognizer.startListening(context: context)
            }
        }
    }
    
    // Reset the ready sound flag once played
    func readySoundWasPlayed() {
        shouldPlayReadySound = false
    }
    
    // Save dialog dismissed
    func handleSaveDialogDismissed() {
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            forceRestartSpeechRecognition()
        }
    }
    
    // Settings dismissed
    func handleSettingsDismissed() {
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            forceRestartSpeechRecognition()
        }
    }
    
    // Handle background/foreground
    func handleAppStateChange(isBackground: Bool) {
        speechRecognizer.handleAppStateChange(isBackground: isBackground)
        if !isBackground {
            // After we return from background, do a forced restart
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                forceRestartSpeechRecognition()
            }
        }
    }
    
    deinit {
        speechRecognizer.cleanup()
        cancellables.removeAll()
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}
