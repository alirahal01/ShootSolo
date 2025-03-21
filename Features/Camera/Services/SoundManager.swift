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
    
    func playStartSound() {
        startSound?.play()
    }
    
    func getStartSoundDuration() -> TimeInterval {
        return startSound?.duration ?? 0
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
    
    func getStopSoundDuration() -> TimeInterval {
        return stopSound?.duration ?? 0
    }
}
