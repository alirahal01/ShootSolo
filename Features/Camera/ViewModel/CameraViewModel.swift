import Foundation
import Combine
import AVFoundation
import SwiftUI

@MainActor
class CameraViewModel: ObservableObject {
    // Add recording state enum
    enum RecordingState {
        case idle
        case starting
        case recording
        case stopping
        case savingDialog
        
        var canStart: Bool {
            self == .idle
        }
        
        var canStop: Bool {
            self == .recording
        }
    }
    
    // Add state property
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
    
    var cameraManager: CameraManager
    private var recordingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    var speechRecognizer: SpeechRecognizer
    @StateObject private var adViewModel = RewardedAdViewModel.shared
    private var lastRecordingStopTime: Date?
    
    // Add a didSet to keep recordingState in sync
    private var recordingState: RecordingState = .idle {
        didSet {
            isRecording = (recordingState == .recording)
        }
    }
    
    // Add a property to track initialization state
    @Published private(set) var isInitialized = false
    
    init(cameraManager: CameraManager = CameraManager()) {
        self.cameraManager = cameraManager
        self.speechRecognizer = SpeechRecognizer()
        
        // Remove the isRecording binding since we're using recordingState now
        
        // Observe credits balance changes using Combine
        CreditsManager.shared.$creditsBalance
            .receive(on: RunLoop.main)
            .assign(to: &$creditCount)
        
        // Set up speech recognizer command handling
        setupSpeechRecognizer()
        
        // Initialize components
        Task { @MainActor in
            await initialize()
        }
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer.onCommandDetected = { [weak self] command in
            Task { [weak self] in
                guard let self = self else { return }
                print("📸 CameraViewModel: Received command: \(command)")
                switch command {
                case "start":
                    if self.recordingState.canStart {
                        print("📸 CameraViewModel: Processing START command")
                        await self.startRecording()
                    } else {
                        print("📸 CameraViewModel: Ignoring START command - current state: \(self.recordingState)")
                    }
                case "stop":
                    if self.recordingState.canStop {
                        print("📸 CameraViewModel: Processing STOP command")
                        await self.stopRecording()
                    } else {
                        print("📸 CameraViewModel: Ignoring STOP command - current state: \(self.recordingState)")
                    }
                case "yes":
                    if case .savingDialog = self.recordingState {
                        print("📸 CameraViewModel: Processing YES command")
                        self.saveTake()
                    }
                case "no":
                    if case .savingDialog = self.recordingState {
                        print("📸 CameraViewModel: Processing NO command")
                        self.discardTake()
                    }
                default:
                    break
                }
            }
        }
    }
    
    private func initialize() async {
        // Ensure we have an ad ready
        if adViewModel.rewardedAd == nil && !adViewModel.isLoading {
            adViewModel.loadAd()
        }
        
        // Wait a moment for components to settle
        try? await Task.sleep(for: .seconds(0.5))
        
        // Initialize speech recognition
        if !speechRecognizer.isListening && !speechRecognizer.hasError {
            speechRecognizer.startListening(context: .camera)
        }
        
        isInitialized = true
    }
    
    // Add a method to restart speech recognition
    func restartSpeechRecognition() {
        print("📸 CameraViewModel: Attempting to restart speech recognition")
        
        // Stop any existing session first
        speechRecognizer.stopListening()
        
        Task { @MainActor in
            // Give a moment for the previous session to fully stop
            try? await Task.sleep(for: .seconds(0.5))  // Increased delay
            
            // Start new listening session with appropriate context
            let context: CommandContext = showingSaveDialog ? .saveDialog : .camera
            
            if speechRecognizer.hasError {
                print("📸 CameraViewModel: Speech recognizer has error, attempting to recover")
                // Try to recover by stopping and starting again
                speechRecognizer.stopListening()
                try? await Task.sleep(for: .seconds(0.5))
            }
            
            speechRecognizer.startListening(context: context)
            
            // Wait a moment to check if start was successful
            try? await Task.sleep(for: .seconds(0.3))
            
            if speechRecognizer.isListening && !speechRecognizer.hasError {
                print("📸 CameraViewModel: Speech recognition restarted successfully")
                // Remove the ready sound from here - it will only be played in saveTake() and discardTake()
            } else {
                print("📸 CameraViewModel: Could not restart speech recognition - isListening: \(speechRecognizer.isListening), hasError: \(speechRecognizer.hasError)")
            }
        }
    }
    
    private var currentFileName: String {
        FileNameGenerator.generateVideoFileName(takeNumber: currentTake)
    }

    // Update recordingState with didSet to keep isRecording in sync
    private func updateRecordingState(_ newState: RecordingState) {
        print("📸 CameraViewModel: State changing from \(recordingState) to \(newState)")
        recordingState = newState
        // isRecording is now automatically updated via didSet
    }
    
    func startRecording() async {
        guard recordingState.canStart else {
            print("📸 CameraViewModel: Cannot start recording in current state: \(recordingState)")
            return
        }
        
        updateRecordingState(.starting)
        
        if await CreditsManager.shared.useCredit() {
            let soundDuration = SoundManager.shared.getStartSoundDuration()
            SoundManager.shared.playStartSound()
            try? await Task.sleep(for: .seconds(soundDuration))
            
            cameraManager.startRecording()
            startTimer()
            updateRecordingState(.recording)
        } else {
            updateRecordingState(.idle)
            showingCreditsView = true
        }
    }
    
    func stopRecording() async {
        guard recordingState.canStop else {
            print("📸 CameraViewModel: Cannot stop recording in current state: \(recordingState)")
            return
        }
        
        updateRecordingState(.stopping)
        
        cameraManager.stopRecording()
        stopTimer()
        
        let stopSoundDuration = SoundManager.shared.getStopSoundDuration()
        SoundManager.shared.playStopSound()
        try? await Task.sleep(for: .seconds(stopSoundDuration))
        
        speechRecognizer.stopListening()
        try? await Task.sleep(for: .seconds(0.3))
        
        updateRecordingState(.savingDialog)
        showingSaveDialog = true
        speechRecognizer.startListening(context: .saveDialog)
    }
    
    func saveTake() {
        guard case .savingDialog = recordingState else { return }
        
        cameraManager.saveTake(fileName: currentFileName)
        currentTake += 1
        
        speechRecognizer.stopListening()
        showingSaveDialog = false
        
        Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(for: .seconds(0.3))
            updateRecordingState(.idle)
            // Explicitly restart speech recognition
            restartSpeechRecognition()
        }
    }
    
    func discardTake() {
        guard case .savingDialog = recordingState else { return }
        
        cameraManager.discardTake()
        
        speechRecognizer.stopListening()
        showingSaveDialog = false
        
        Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(for: .seconds(0.3))
            updateRecordingState(.idle)
            // Explicitly restart speech recognition
            restartSpeechRecognition()
        }
    }
    
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
    
    func startTimer() {
        recordingTime = 0
        updateTimerText()
        stopTimer(resetText: false)
        
        // Create timer on the main thread - use [weak self]
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                // Only increment if still recording
                if self.isRecording {
                    self.recordingTime += 1
                    self.updateTimerText()
                } else {
                    self.stopTimer()
                }
            }
            
            // Make sure timer runs in common modes (works during scrolling etc)
            if let timer = self.recordingTimer {
                timer.tolerance = 0.1
                RunLoop.current.add(timer, forMode: .common)
            }
        }
    }
    
    func stopTimer(resetText: Bool = true) {
        // Invalidate on main thread - use [weak self]
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
        // Guard against negative times
        guard recordingTime >= 0 else {
            timerText = "00:00:00"
            return
        }
        
        let hours = Int(recordingTime / 3600)
        let minutes = Int((recordingTime % 3600) / 60)
        let seconds = Int(recordingTime % 60)
        
        if hours > 0 {
            // Show hours when recording exceeds 1 hour
            timerText = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            // Show only minutes and seconds when under 1 hour
            timerText = String(format: "%02d:%02d", minutes, seconds)
        }
    }

    deinit {
        print("CameraViewModel deinit started")
        
        // Clear any remaining closures and clean up resources
        speechRecognizer.onCommandDetected = nil
        
        // Cancel all subscriptions
        cancellables.removeAll()
        
        // Stop timer and nil it out
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        print("CameraViewModel deinit completed")
    }
}
