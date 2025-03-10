import Foundation
// SettingsManager.swift
//@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager(authService: AuthenticationService.shared)
    
    @Published var settings: SettingsModel
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
        // First sign out from auth service
        try await authService.signOut()
        
        // Then update local state
        await MainActor.run {
            // Reset settings to default if needed
            settings = SettingsModel.defaultSettings
        }
    }
    
    func deleteAccount() async throws {
        // First delete user's credits from Firestore
        try await CreditsManager.shared.deleteUserCredits()
        
        // Then delete the account
        try await authService.deleteAccount()
        
        // Finally sign out and reset settings
        try await signOut() // This will handle the sign out flow
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
