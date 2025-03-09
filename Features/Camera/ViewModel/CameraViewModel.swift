import Foundation
import Combine
import AVFoundation
import SwiftUI

@MainActor
class CameraViewModel: ObservableObject {
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
    
    init(cameraManager: CameraManager = CameraManager()) {
        self.cameraManager = cameraManager
        self.speechRecognizer = SpeechRecognizer()
        
        // Bind camera manager's state to view model
        cameraManager.$isRecording
            .receive(on: RunLoop.main)
            .assign(to: &$isRecording)
        
        // Observe credits balance changes using Combine
        CreditsManager.shared.$creditsBalance
            .receive(on: RunLoop.main)
            .assign(to: &$creditCount)
        
        // Set up speech recognizer command handling with [weak self]
        speechRecognizer.onCommandDetected = { [weak self] command in
            Task { [weak self] in
                guard let self = self else { return }
                switch command {
                case "start":
                    await self.startRecording()
                case "stop":
                    self.stopRecording()
                case "yes":
                    self.saveTake()
                case "no":
                    self.discardTake()
                default:
                    break
                }
            }
        }
        
        // Start preloading ads when camera view model is initialized
        Task { @MainActor in
            // Ensure we have an ad ready when user runs out of credits
            if adViewModel.rewardedAd == nil && !adViewModel.isLoading {
                adViewModel.loadAd()
            }
        }
    }

    private var currentFileName: String {
        FileNameGenerator.generateVideoFileName(takeNumber: currentTake)
    }

    func startRecording() async {
        // Guard against already recording state
        guard !isRecording else {
            print("Already recording, ignoring start command")
            return
        }
        
        if await CreditsManager.shared.useCredit() {
            // Get sound duration first
            let soundDuration = SoundManager.shared.getStartSoundDuration()
            
            // Play the sound
            SoundManager.shared.playStartSound()
            
            // Wait for sound to finish
            try? await Task.sleep(for: .seconds(soundDuration))
            
            // Then start recording
            cameraManager.startRecording()
            startTimer()
        } else {
            showingCreditsView = true
        }
    }
    
    func stopRecording() {
        SoundManager.shared.playStopSound()
        speechRecognizer.stopListening()  // Stop camera context listening
        cameraManager.stopRecording()
        isRecording = false
        stopTimer()
        
        // Start save dialog context listening before showing dialog
        speechRecognizer.startListening(context: .saveDialog)
        showingSaveDialog = true
        
        print("Recording stopped, showing save dialog")
    }
        
    func saveTake() {
        cameraManager.saveTake(fileName: currentFileName)
        currentTake += 1
        showingSaveDialog = false
        // Start camera context listening after dialog closes
        speechRecognizer.startListening(context: .camera)
        
        // Add delay before playing ready sound - use [weak self]
        Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(for: .seconds(1)) // Wait for success sound to finish
            if self.cameraManager.isReady && !self.speechRecognizer.hasError {
                SoundManager.shared.playReadySound()
            }
        }
    }
    
    func discardTake() {
        cameraManager.discardTake()
        showingSaveDialog = false
        // Start camera context listening after dialog closes
        speechRecognizer.startListening(context: .camera)
        
        // Add delay before playing ready sound - use [weak self]
        Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(for: .seconds(1)) // Wait for trash sound to finish
            if self.cameraManager.isReady && !self.speechRecognizer.hasError {
                SoundManager.shared.playReadySound()
            }
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
