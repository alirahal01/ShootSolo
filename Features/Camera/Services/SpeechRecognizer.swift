import Foundation
import Speech

enum CommandContext {
    case camera
    case saveDialog
}

class SpeechRecognizer: NSObject, ObservableObject {
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var isListening = false
    @Published var hasError = false
    @Published var errorMessage: String?
    @Published var isInitializing = true
    @Published var isWaitingForSpeech = false
    @Published var lastDetectedCommand: String?
    
    var onCommandDetected: ((String) -> Void)?
    
    private var settingsManager: SettingsManager
    private var currentContext: CommandContext = .camera
    private var isStarting = false
    private var isAuthorized = false
    
    // Add a flag to track if we're being deallocated
    private var isBeingDeallocated = false
    
    private var isInBackground = false
    
    init(settingsManager: SettingsManager = SettingsManager.shared) {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        self.settingsManager = settingsManager
        super.init()
        
        print("🎤 SpeechRecognizer: Initializing...")
        
        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            print("🎤 SpeechRecognizer: Authorization status: \(status)")
            
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("🎤 SpeechRecognizer: Authorization granted")
                    self?.isAuthorized = true
                    self?.hasError = false
                    self?.isInitializing = false
                    
                    // Try to start listening after authorization
                    if let self = self {
                        print("🎤 SpeechRecognizer: Auto-starting after authorization")
                        self.startListening(context: .camera)
                    }
                    
                case .denied:
                    print("🎤 SpeechRecognizer: Authorization denied")
                    self?.handleAuthorizationFailure("Speech recognition denied")
                case .restricted:
                    print("🎤 SpeechRecognizer: Authorization restricted")
                    self?.handleAuthorizationFailure("Speech recognition restricted")
                case .notDetermined:
                    print("🎤 SpeechRecognizer: Authorization not determined")
                    self?.handleAuthorizationFailure("Speech recognition not authorized")
                @unknown default:
                    print("🎤 SpeechRecognizer: Unknown authorization status")
                    self?.handleAuthorizationFailure("Unknown authorization status")
                }
            }
        }
    }
    
    private func handleAuthorizationFailure(_ message: String) {
        isAuthorized = false
        hasError = true
        errorMessage = message
        isInitializing = false
        print("🎤 SpeechRecognizer: Authorization failed - \(message)")
    }
    
    func startListening(context: CommandContext) {
        print("🎤 Starting speech recognition for context: \(context), current state - isListening: \(isListening), isStarting: \(isStarting), hasError: \(hasError)")
        
        // Don't restart if already listening to same context
        if isListening && currentContext == context && !hasError {
            print("🎤 Already listening to context: \(context)")
            return
        }
        
        guard isAuthorized else {
            print("🎤 Cannot start - not authorized")
            hasError = true
            errorMessage = "Speech recognition not authorized"
            return
        }
        
        // Force reset if in a bad state
        if isStarting || hasError {
            print("🎤 Force resetting state before starting")
            stopListening()
            isStarting = false
            hasError = false
        }
        
        guard let sr = speechRecognizer, sr.isAvailable else {
            print("🎤 Speech recognizer not available")
            hasError = true
            errorMessage = "Speech recognizer not available"
            return
        }
        
        print("🎤 Starting speech recognition for context: \(context)")
        
        // Stop any existing recognition first
        stopListening()
        
        // Don't set isInitializing when switching contexts
        if context != currentContext {
            print("🎤 Switching context from \(currentContext) to \(context)")
            isInitializing = false
        }
        
        // Update state immediately to show we're starting
        isStarting = true
        isListening = false
        hasError = false
        errorMessage = "Initializing speech recognition..."
        currentContext = context
        
        print("🎤 States after initial setup - isStarting: \(isStarting), isListening: \(isListening), isInitializing: \(isInitializing)")
        
        // Create new recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("🎤 Could not create recognition request")
            isStarting = false
            hasError = true
            errorMessage = "Failed to create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .confirmation
        
        print("🎤 Creating recognition task...")
        
        // Create recognition task with detailed logging
        recognitionTask = sr.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else {
                print("🎤 Self was deallocated in recognition task")
                return
            }
            
            // Set listening state immediately when task starts
            DispatchQueue.main.async {
                // Always update isStarting regardless of previous state
                self.isStarting = false
                
                if error == nil {
                    self.isListening = true
                    self.hasError = false
                    self.errorMessage = nil
                    print("🎤 Speech recognition task started - isListening now true")
                }
            }
            
            if let error = error {
                print("🎤 Speech recognition error: \(error.localizedDescription)")
                self.handleRecognitionError(error)
                return
            }
            
            if let result = result {
                print("🎤 Recognition result: \(result.bestTranscription.formattedString)")
                DispatchQueue.main.async {
                    self.processResult(result)
                }
            }
        }
        
        // If task creation failed immediately
        if recognitionTask == nil {
            print("🎤 Failed to create recognition task")
            isStarting = false
            hasError = true
            errorMessage = "Failed to create recognition task"
        }
    }
    
    private func handleRecognitionError(_ error: Error) {
        print("🎤❌ SpeechRecognizer: Recognition error: \(error.localizedDescription)")

        // If it's the "no speech detected" error, set waiting state
        if error.localizedDescription.contains("No speech detected") {
            print("🎤 No speech detected, continuing to listen...")
            DispatchQueue.main.async {
                self.isWaitingForSpeech = true
                // Keep listening state true
                self.isListening = true
                self.hasError = false
            }
            return
        }
        
        // For real errors, set error state
        DispatchQueue.main.async {
            self.hasError = true
            self.isListening = false
            self.isInitializing = false
            self.isWaitingForSpeech = false
            self.errorMessage = error.localizedDescription
        }
    }

    private func processResult(_ result: SFSpeechRecognitionResult) {
        // When we get any result, we're not waiting anymore
        DispatchQueue.main.async {
            self.isWaitingForSpeech = false
        }
        
        let text = result.bestTranscription.formattedString.lowercased()
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        switch currentContext {
        case .camera:
            if words.count >= 2 {
                let lastTwoWords = Array(words.suffix(2)).joined(separator: " ")
                if settingsManager.isStartCommand(lastTwoWords) {
                    print("🎤 ✅ ✅ ✅ SpeechRecognizer: Detected START command: '\(lastTwoWords)'")
                    DispatchQueue.main.async {
                        self.lastDetectedCommand = "START"
                    }
                    onCommandDetected?("start")
                } else if settingsManager.isStopCommand(lastTwoWords) {
                    print("🎤 ✅ ✅ ✅ SpeechRecognizer: Detected STOP command: '\(lastTwoWords)'")
                    DispatchQueue.main.async {
                        self.lastDetectedCommand = "STOP"
                    }
                    onCommandDetected?("stop")
                }
            }
        case .saveDialog:
            if let lastWord = words.last {
                if lastWord == "yes" {
                    print("🎤 ✅ ✅ ✅ SpeechRecognizer: Detected YES command")
                    DispatchQueue.main.async {
                        self.lastDetectedCommand = "YES"
                    }
                    onCommandDetected?("yes")
                } else if lastWord == "no" {
                    print("🎤 ✅ ✅ ✅ SpeechRecognizer: Detected NO command")
                    DispatchQueue.main.async {
                        self.lastDetectedCommand = "NO"
                    }
                    onCommandDetected?("no")
                }
            }
        }
        
        // Clear last detected command after a delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.0))
            self.lastDetectedCommand = nil
        }
    }
    
    func cleanup() {
        isBeingDeallocated = true
        
        stopListening()
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        isListening = false
        hasError = false
        errorMessage = nil
        isInitializing = false
    }
    
    func stopListening() {
        isListening = false
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
    }
    
    // Add method to receive audio samples from CameraManager
    func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // First check authorization
        guard isAuthorized else {
            print("🎤 Buffer skipped - not authorized")
            return
        }
        
        // Then check listening state
        guard isListening else {
            print("🎤 Buffer skipped - isListening: \(isListening), isStarting: \(isStarting), hasError: \(hasError), isAuthorized: \(isAuthorized)")
            return
        }
        
        guard let recognitionRequest = recognitionRequest else {
            print("🎤 Buffer skipped - recognitionRequest is nil, but isListening is true")
            // This shouldn't happen - fix the state
            isListening = false
            return
        }
        
        // Process the buffer
        recognitionRequest.appendAudioSampleBuffer(sampleBuffer)
    }
    
    deinit {
        cleanup()
    }
    
    func handleAppStateChange(isBackground: Bool) {
        print("🎤 SpeechRecognizer: App state changed, isBackground: \(isBackground)")
        
        if isBackground {
            self.isInBackground = true
            stopListening()
            print("🎤 SpeechRecognizer: Stopped listening due to background state")
        } else {
            self.isInBackground = false
            isStarting = false // Reset starting state
            hasError = false // Clear any errors
            isInitializing = false // Not initializing
            print("🎤 SpeechRecognizer: Reset state after background")
        }
    }
}
