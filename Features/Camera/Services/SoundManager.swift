import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    
    private var startSound: AVAudioPlayer?
    private var stopSound: AVAudioPlayer?
    private var readySound: AVAudioPlayer?
    private var saveTakeSound: AVAudioPlayer?
    
    private init() {
        setupSounds()
    }
    
    private func setupSounds() {
        if let startPath = Bundle.main.path(forResource: "blip_start", ofType: "mp3") {
            startSound = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: startPath))
            startSound?.prepareToPlay()
        }
        
        if let stopPath = Bundle.main.path(forResource: "blip_stop", ofType: "mp3") {
            stopSound = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: stopPath))
            stopSound?.prepareToPlay()
        }
        
        if let readyPath = Bundle.main.path(forResource: "ready_to_record", ofType: "mp3") {
            readySound = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: readyPath))
            readySound?.prepareToPlay()
        }
        
        if let savePath = Bundle.main.path(forResource: "save_take", ofType: "mp3") {
            saveTakeSound = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: savePath))
            saveTakeSound?.prepareToPlay()
        }
    }
    
    // Add speech recognizer status check helper
    private func canPlaySound(speechRecognizer: SpeechRecognizer? = nil) -> Bool {
        // If no speech recognizer is provided, allow sound
        guard let speechRecognizer = speechRecognizer else { return true }
        return speechRecognizer.isListening && !speechRecognizer.hasError
    }
    
    func playStartSound() {
        startSound?.play()
    }
    
    func getStartSoundDuration() -> TimeInterval {
        return startSound?.duration ?? 0
    }
    
    func playStopSound() {
        stopSound?.play()
    }
    
    func getStopSoundDuration() -> TimeInterval {
        return stopSound?.duration ?? 0
    }
    
    func playReadySound(speechRecognizer: SpeechRecognizer? = nil) {
        guard canPlaySound(speechRecognizer: speechRecognizer) else {
            print("🔊 SoundManager: Skipping ready sound - speech recognition not working")
            return
        }
        readySound?.play()
    }
    
    func playSaveTakeSound(speechRecognizer: SpeechRecognizer? = nil) {
        guard canPlaySound(speechRecognizer: speechRecognizer) else {
            print("🔊 SoundManager: Skipping save take sound - speech recognition not working")
            return
        }
        saveTakeSound?.play()
    }
}
