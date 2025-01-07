import Foundation
import Combine
import AVFoundation
import SwiftUI

class CameraViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isGridEnabled = false
    @Published var isFlashOn = false
    @Published var currentTake = 1
    @Published var zoomFactor: CGFloat = 1.0
    @Published var recordingTime: Int = 0
    @Published var showingSaveDialog = false
    @Published var timerText: String = "00:00"
    @Published var creditCount = 0
    
    var cameraManager: CameraManager
    private var recordingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    var speechRecognizer: SpeechRecognizer

    init(cameraManager: CameraManager = CameraManager()) {
        self.cameraManager = cameraManager
        self.speechRecognizer = SpeechRecognizer()
        
        // Bind camera manager's state to view model
        cameraManager.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
        
        // Set up speech recognizer command handling
        speechRecognizer.onCommandDetected = { [weak self] command in
            switch command {
            case "start":
                self?.startRecording()
            case "stop":
                self?.stopRecording()
            default:
                break
            }
        }
    }

    func startRecording() {
        cameraManager.startRecording()
        startTimer()
        creditCount += 1
    }
    
    func stopRecording() {
        cameraManager.stopRecording()
        stopTimer()
        showingSaveDialog = true
    }
    
    func saveTake() {
        cameraManager.saveTake()
        currentTake += 1
        showingSaveDialog = false
    }
    
    func discardTake() {
        cameraManager.discardTake()
        showingSaveDialog = false
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
