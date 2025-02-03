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
        if let startPath = Bundle.main.path(forResource: "Blip Start", ofType: "mp3") {
            startSound = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: startPath))
            startSound?.prepareToPlay()
        }
        
        if let stopPath = Bundle.main.path(forResource: "Blip Stop", ofType: "mp3") {
            stopSound = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: stopPath))
            stopSound?.prepareToPlay()
        }
        
        if let readyPath = Bundle.main.path(forResource: "Ready to Record", ofType: "mp3") {
            readySound = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: readyPath))
            readySound?.prepareToPlay()
        }
        
        if let savePath = Bundle.main.path(forResource: "Save Take", ofType: "mp3") {
            saveTakeSound = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: savePath))
            saveTakeSound?.prepareToPlay()
        }
    }
    
    func playStartSound() {
        startSound?.play()
    }
    
    func playStopSound() {
        stopSound?.play()
    }
    
    func playReadySound() {
        readySound?.play()
    }
    
    func playSaveTakeSound() {
        saveTakeSound?.play()
    }
} 