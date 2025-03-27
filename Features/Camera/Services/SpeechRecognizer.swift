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
    private let audioEngine = AVAudioEngine()
    
    @Published var isListening = false
    @Published var hasError = false
    @Published var errorMessage: String?
    
    var onCommandDetected: ((String) -> Void)?
    
    private var settingsManager: SettingsManager
    private var currentContext: CommandContext = .camera
    private var isStarting = false
    private var isAuthorized = false
    
    init(settingsManager: SettingsManager = SettingsManager.shared) {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        self.settingsManager = settingsManager
        super.init()
        
        // Request speech recognition authorization on init
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.isAuthorized = true
                    self?.setupAudioSession()
                    self?.hasError = false
                case .denied, .restricted, .notDetermined:
                    self?.isAuthorized = false
                    self?.hasError = true
                    self?.errorMessage = "Speech recognition not authorized"
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // First deactivate the session
            try? audioSession.setActive(false)
            
            try audioSession.setCategory(.playAndRecord,
                                      mode: .default,
                                      options: [.allowBluetooth, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Reset error state after successful setup
            hasError = false
            errorMessage = nil
            
        } catch {
            print("Audio session setup failed: \(error)")
            hasError = true
            errorMessage = "Audio session setup failed"
        }
    }
    
    func startListening(context: CommandContext) {
        print("🎤 SpeechRecognizer: Starting listening for context: \(context)")
        
        // Check authorization first
        guard isAuthorized else {
            print("🎤❌ SpeechRecognizer: Not authorized")
            hasError = true
            errorMessage = "Speech recognition not authorized"
            return
        }
        
        // Prevent multiple simultaneous start attempts
        guard !isStarting else {
            print("🎤 SpeechRecognizer: Already starting, ignoring request")
            return
        }
        
        isStarting = true
        
        // Reset error state when starting
        hasError = false
        errorMessage = nil
        currentContext = context
        
        // First, ensure we're fully stopped
        stopCurrentRecognitionTask()
        
        // Ensure audio session is properly set up
        setupAudioSession()
        
        // Then start fresh
        Task { @MainActor in
            do {
                try await startRecognition()
                isStarting = false
            } catch {
                print("🎤❌ SpeechRecognizer: Failed to start: \(error)")
                handleRecognitionError(error)
                isStarting = false
            }
        }
    }
    
    private func startRecognition() async throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw NSError(domain: "SpeechRecognizer", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
        }
        
        // First ensure we're fully stopped and cleaned up
        stopCurrentRecognitionTask()
        
        // Reset audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false)
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("🎤❌ SpeechRecognizer: Failed to configure audio session: \(error)")
            throw error
        }
        
        // Create new recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "SpeechRecognizer", code: -2, 
                         userInfo: [NSLocalizedDescriptionKey: "Could not create recognition request"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .confirmation
        
        // Configure audio engine and input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Create recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleRecognitionError(error)
                return
            }
            
            DispatchQueue.main.async {
                if let result = result {
                    self.processResult(result)
                }
            }
        }
        
        // Important: Wait a bit before configuring audio
        try await Task.sleep(for: .milliseconds(100))
        
        // Prepare audio engine
        audioEngine.prepare()
        
        // Remove any existing tap first
        if audioEngine.isRunning {
            inputNode.removeTap(onBus: 0)
        }
        
        // Install new tap
        inputNode.installTap(onBus: 0,
                            bufferSize: 1024,
                            format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        try audioEngine.start()
        
        // Ensure state updates happen on main thread
        await MainActor.run {
            isListening = true
            hasError = false
            errorMessage = nil
        }
    }
    
    private func handleRecognitionError(_ error: Error) {
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("🎤❌ SpeechRecognizer: Recognition error: \(error.localizedDescription)")
            let nsError = error as NSError
            
            switch nsError.domain {
            case "kAFAssistantErrorDomain":
                switch nsError.code {
                case 1110, 1101:
                    self.errorMessage = "No speech detected"
                default:
                    self.errorMessage = "Recognition error occurred: \(error.localizedDescription)"
                }
            default:
                self.errorMessage = "Recognition error occurred: \(error.localizedDescription)"
            }
            
            self.hasError = true
            self.isListening = false
        }
        
        // Try to recover from error
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            setupAudioSession()  // Try to reset audio session
        }
    }
    
    private func processResult(_ result: SFSpeechRecognitionResult) {
        let text = result.bestTranscription.formattedString.lowercased()
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        switch currentContext {
        case .camera:
            if words.count >= 2 {
                let lastTwoWords = Array(words.suffix(2)).joined(separator: " ")
                if settingsManager.isStartCommand(lastTwoWords) {
                    print("🎤 SpeechRecognizer: Detected START command")
                    onCommandDetected?("start")
                } else if settingsManager.isStopCommand(lastTwoWords) {
                    print("🎤 SpeechRecognizer: Detected STOP command")
                    onCommandDetected?("stop")
                }
            }
        case .saveDialog:
            if let lastWord = words.last {
                if lastWord == "yes" {
                    print("🎤 SpeechRecognizer: Detected YES command")
                    onCommandDetected?("yes")
                } else if lastWord == "no" {
                    print("🎤 SpeechRecognizer: Detected NO command")
                    onCommandDetected?("no")
                }
            }
        }
    }
    
    func stopListening() {
        print("🎤 SpeechRecognizer: Stopping listening for context: \(currentContext)")
        stopCurrentRecognitionTask()
        
        // Ensure state update happens on main thread
        DispatchQueue.main.async { [weak self] in
            self?.isListening = false
        }
    }
    
    private func stopCurrentRecognitionTask() {
        // Stop audio engine first
        if audioEngine.isRunning {
            audioEngine.stop()
            
            // Remove tap with a slight delay to ensure proper cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.audioEngine.inputNode.removeTap(onBus: 0)
            }
        }
        
        // Then cleanup recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Finally cleanup request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
    }
    
    deinit {
        stopListening()
    }
}
