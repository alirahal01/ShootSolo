import Foundation

// RecordingKeywords.swift
enum RecordingKeywords: String, Codable, CaseIterable {
    case heyAction = "Camera Start"
    case start = "Record Begin"
    case startNow = "Action Rolling"
    case go = "Rolling Camera"
    
    static var defaultStartKeyword: RecordingKeywords {
        .heyAction
    }
}

enum StopKeywords: String, Codable, CaseIterable {
    case heyCut = "Camera Stop"
    case stop = "Record End"
    case stopNow = "Action Cut"
    case cut = "Cut Rolling"
    
    static var defaultStopKeyword: StopKeywords {
        .heyCut
    }
}

// VideoSettings.swift
struct VideoSettings: Codable {
    var resolution: Resolution
    var framerate: Framerate
    
    enum Resolution: String, Codable, CaseIterable {
        case uhd4k = "4K (3840x2160)"
        case qhd = "2K (2560x1440)"
        case fullHd = "1080p (1920x1080)"
        case hd = "720p (1280x720)"
    }
    
    enum Framerate: String, Codable, CaseIterable {
        case fps30 = "30 FPS"
        case fps60 = "60 FPS"
        case fps120 = "120 FPS"
    }
}

// SettingsModel.swift
struct SettingsModel: Codable {
    var selectedStartKeyword: RecordingKeywords
    var selectedStopKeyword: StopKeywords
    var videoSettings: VideoSettings
    var fileNameFormat: String
    var saveLocation: String
    
    static var defaultSettings: SettingsModel {
        return SettingsModel(
            selectedStartKeyword: .heyAction,
            selectedStopKeyword: .heyCut,
            videoSettings: VideoSettings(
                resolution: .uhd4k,
                framerate: .fps60
            ),
            fileNameFormat: "Take [n]",
            saveLocation: "Gallery"
        )
    }
}

// SettingsPersistable.swift
protocol SettingsPersistable {
    func save(_ settings: SettingsModel) throws
    func load() throws -> SettingsModel
}

// AuthenticationProtocol.swift
protocol AuthenticationProtocol {
    var currentUser: UserModel? { get }
    func signOut() async throws
    func deleteAccount() async throws
}

// UserDefaultsSettingsStorage.swift
class UserDefaultsSettingsStorage: SettingsPersistable {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let key = "userSettings"
    
    func save(_ settings: SettingsModel) throws {
        let data = try encoder.encode(settings)
        UserDefaults.standard.set(data, forKey: key)
    }
    
    func load() throws -> SettingsModel {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return SettingsModel.defaultSettings
        }
        return try decoder.decode(SettingsModel.self, from: data)
    }
}
