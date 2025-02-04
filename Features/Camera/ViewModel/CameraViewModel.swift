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
        
        // Set up speech recognizer command handling
        speechRecognizer.onCommandDetected = { [weak self] command in
            Task { @MainActor in
                switch command {
                case "start":
                    await self?.startRecording()
                case "stop":
                    self?.stopRecording()
                case "yes":
                    self?.saveTake()
                case "no":
                    self?.discardTake()
                default:
                    break
                }
            }
        }
    }

    func startRecording() async {
        if await CreditsManager.shared.useCredit() {
            SoundManager.shared.playStartSound()
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
        cameraManager.saveTake()
        currentTake += 1
        showingSaveDialog = false
        // Start camera context listening after dialog closes
        speechRecognizer.startListening(context: .camera)
        
        // Add delay before playing ready sound
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1)) // Wait for success sound to finish
            if cameraManager.isReady && !speechRecognizer.hasError {
                SoundManager.shared.playReadySound()
            }
        }
    }
    
    func discardTake() {
        cameraManager.discardTake()
        showingSaveDialog = false
        // Start camera context listening after dialog closes
        speechRecognizer.startListening(context: .camera)
        
        // Add delay before playing ready sound
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1)) // Wait for trash sound to finish
            if cameraManager.isReady && !speechRecognizer.hasError {
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
    
    private func startTimer() {
        recordingTime = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording else {
                self?.recordingTimer?.invalidate()
                return
            }
            self.recordingTime += 1
            self.updateTimerText()
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingTime = 0
        updateTimerText()
    }
    
    private func updateTimerText() {
        let minutes = recordingTime / 60
        let seconds = recordingTime % 60
        timerText = String(format: "%02d:%02d", minutes, seconds)
    }
} 
