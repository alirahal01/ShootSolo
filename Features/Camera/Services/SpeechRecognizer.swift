import Foundation
import Speech

enum CommandContext {
    case camera
    case saveDialog
}

class SpeechRecognizer: NSObject, ObservableObject {
    private let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var isListening = false
    @Published var hasError = false
    @Published var errorMessage: String?
    @Published var isInitializing = true
    @Published var isWaitingForSpeech = false
    
    var onCommandDetected: ((String) -> Void)?
    
    private var currentContext: CommandContext = .camera
    private var isAuthorized = false
    
    private var settingsManager = SettingsManager.shared
    
    override init() {
        super.init()
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch status {
                case .authorized:
                    self.isAuthorized = true
                    self.hasError = false
                    self.isInitializing = false
                    // Auto-start in camera context
                    self.startListening(context: .camera)
                case .denied:
                    self.handleAuthorizationFailure("Speech recognition denied")
                case .restricted:
                    self.handleAuthorizationFailure("Speech recognition restricted")
                case .notDetermined:
                    self.handleAuthorizationFailure("Speech recognition not authorized")
                @unknown default:
                    self.handleAuthorizationFailure("Unknown authorization status")
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
    
    // MARK: - Start/Stop Listening
    
    func startListening(context: CommandContext) {
        // Always stop first to ensure a fresh request
        stopListening()
        
        guard isAuthorized, let sr = speechRecognizer, sr.isAvailable else {
            hasError = true
            errorMessage = "Speech recognizer not available"
            return
        }
        
        print("🎤 Starting speech recognition for context: \(context)")
        
        self.currentContext = context
        self.isInitializing = false
        self.hasError = false
        self.errorMessage = nil
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            hasError = true
            errorMessage = "Failed to create recognition request"
            return
        }
        
        request.shouldReportPartialResults = true
        request.taskHint = .confirmation
        
        recognitionTask = sr.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                self.handleRecognitionError(error)
                return
            }
            if let result = result {
                self.processResult(result)
            }
        }
        
        // If everything set up OK, update states
        self.isListening = true
        self.isWaitingForSpeech = false
    }
    
    func stopListening() {
        print("🎤 Stopping speech recognition")
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        isListening = false
        isWaitingForSpeech = false
        // We do not clear “hasError” or “errorMessage” here, in case an error was reported
    }
    
    private func handleRecognitionError(_ error: Error) {
        print("🎤❌ SpeechRecognizer: Recognition error: \(error.localizedDescription)")
        if error.localizedDescription.contains("No speech detected") {
            print("🎤 No speech detected, keep listening state true but note waiting")
            DispatchQueue.main.async {
                self.isWaitingForSpeech = true
            }
            return
        }
        // For real errors, set error state
        DispatchQueue.main.async {
            self.isListening = false
            self.hasError = true
            self.errorMessage = error.localizedDescription
        }
        // Attempt auto-restart after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startListening(context: self.currentContext)
        }
    }
    
    private func processResult(_ result: SFSpeechRecognitionResult) {
        self.isWaitingForSpeech = false
        let text = result.bestTranscription.formattedString.lowercased()
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        switch currentContext {
        case .camera:
            if words.count >= 2 {
                let lastTwoWords = Array(words.suffix(2)).joined(separator: " ")
                if settingsManager.isStartCommand(lastTwoWords) {
                    onCommandDetected?("start")
                } else if settingsManager.isStopCommand(lastTwoWords) {
                    onCommandDetected?("stop")
                }
            }
        case .saveDialog:
            if let lastWord = words.last {
                if lastWord == "yes" {
                    onCommandDetected?("yes")
                } else if lastWord == "no" {
                    onCommandDetected?("no")
                }
            }
        }
    }
    
    // MARK: - Append Audio Buffer
    func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isAuthorized, isListening, let request = recognitionRequest else { return }
        request.appendAudioSampleBuffer(sampleBuffer)
    }
    
    // MARK: - App State Changes
    func handleAppStateChange(isBackground: Bool) {
        if isBackground {
            stopListening()
        } else {
            // Do nothing special here. Let higher-level code call startListening() if needed.
        }
    }
    
    func cleanup() {
        stopListening()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
}
