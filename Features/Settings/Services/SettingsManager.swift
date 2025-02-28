import Foundation
// SettingsManager.swift
//@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager(authService: AuthenticationService.shared)
    
    @Published private(set) var settings: SettingsModel
    private let storage: SettingsPersistable
    let authService: AuthenticationProtocol
    
    private init(
        storage: SettingsPersistable = UserDefaultsSettingsStorage(),
        authService: AuthenticationProtocol
    ) {
        self.storage = storage
        self.authService = authService
        self.settings = SettingsModel.defaultSettings
        loadSettings()
    }
    
    private func loadSettings() {
        do {
            settings = try storage.load()
        } catch {
            print("Error loading settings: \(error)")
        }
    }
    
    func updateSettings(_ newSettings: SettingsModel) {
        do {
            try storage.save(newSettings)
            settings = newSettings
        } catch {
            print("Error saving settings: \(error)")
        }
    }
    
    func signOut() async throws {
        try await authService.signOut()
    }
    
    func deleteAccount() async throws {
        try await authService.deleteAccount()
    }
}

// MARK: - Voice Command Helpers
extension SettingsManager {
    func isStartCommand(_ spokenPhrase: String) -> Bool {
        spokenPhrase.lowercased() == settings.selectedStartKeyword.rawValue.lowercased()
    }
    
    func isStopCommand(_ spokenPhrase: String) -> Bool {
        spokenPhrase.lowercased() == settings.selectedStopKeyword.rawValue.lowercased()
    }
}
