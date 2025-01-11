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
    
    init(settingsManager: SettingsManager = SettingsManager.shared) {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        self.settingsManager = settingsManager
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    func startListening(context: CommandContext) {
        currentContext = context
        startRecognition()
    }
    
    private func startRecognition() {
        stopCurrentRecognitionTask()
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer not available"
            hasError = true
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .confirmation
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleRecognitionError(error)
                return
            }
            
            if let result = result {
                self.processResult(result)
            }
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            hasError = false
            errorMessage = nil
        } catch {
            print("Audio engine failed to start: \(error)")
            errorMessage = "Failed to start listening"
            hasError = true
        }
    }
    
    private func handleRecognitionError(_ error: Error) {
        let nsError = error as NSError
        print("Recognition error: \(error.localizedDescription)")
        
        switch nsError.domain {
        case "kAFAssistantErrorDomain":
            switch nsError.code {
            case 1110, 1101:
                errorMessage = "No speech detected"
            default:
                errorMessage = "Recognition error occurred"
            }
        default:
            errorMessage = "Recognition error occurred"
        }
        
        hasError = true
        isListening = false
        stopCurrentRecognitionTask()
    }
    
    private func processResult(_ result: SFSpeechRecognitionResult) {
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
    
    func stopListening() {
        stopCurrentRecognitionTask()
        isListening = false
    }
    
    private func stopCurrentRecognitionTask() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    deinit {
        stopListening()
    }
}
