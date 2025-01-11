import Foundation
import Speech

class SpeechRecognizer: NSObject, ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var isListening = false
    var onCommandDetected: ((String) -> Void)?
    
    private var settingsManager: SettingsManager

    init(settingsManager: SettingsManager = SettingsManager.shared) {
        self.settingsManager = settingsManager
        super.init()
        requestAuthorization()
        requestMicrophonePermission()
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("Microphone permission granted")
                } else {
                    print("Microphone permission denied")
                }
            }
        }
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    print("Speech recognition authorization denied")
                case .restricted:
                    print("Speech recognition restricted")
                case .notDetermined:
                    print("Speech recognition not determined")
                @unknown default:
                    print("Speech recognition unknown status")
                }
            }
        }
    }
    
    func startListening() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
               print("Speech recognizer not available")
               return
           }
        guard !isListening else { return }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            var isFinal = false
            
            if let result = result {
                let fullText = result.bestTranscription.formattedString.lowercased()
                isFinal = result.isFinal
                
                // Split into words and get last two
                let words = fullText.components(separatedBy: .whitespacesAndNewlines)
                print("[SpeechRecognizer <><> recognized words: \(words)]")
                if words.count >= 2 {
                    let lastTwoWords = Array(words.suffix(2))
                    print("Last two words: \(lastTwoWords)")
                    
                    // Check exact match for both words
                    if self.settingsManager.isStartCommand(lastTwoWords.joined(separator: " ")) {
                        print("Start command detected")
                        self.onCommandDetected?("start")
                    } else if self.settingsManager.isStopCommand(lastTwoWords.joined(separator: " ")) {
                        print("Stop command detected")
                        self.onCommandDetected?("stop")
                    }
                }
            }
            
            if let error = error {
                print("Recognition error: \(error.localizedDescription)")
                self.stopListening()
                
                // Add delay before restart
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.startListening()
                }
                return
            }

            if isFinal {
                self.stopListening()
                // Add delay before restart
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startListening()
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
} 
