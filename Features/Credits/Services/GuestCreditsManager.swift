import Foundation
import Security
@MainActor
class GuestCreditsManager {
    static let shared = GuestCreditsManager()
    
    private let userDefaults = UserDefaults.standard
    private let deviceIdKey = "deviceUniqueId"
    private let guestCreditsInitializedKey = "guestCreditsInitialized"
    private let initialGuestCredits = 20
    
    private init() {}
    
    private func getOrCreateDeviceId() -> String {
        // Try to get existing device ID from Keychain
        if let existingId = KeychainHelper.load(key: deviceIdKey) as? String {
            return existingId
        }
        
        // Create new device ID if none exists
        let newId = UUID().uuidString
        KeychainHelper.save(newId, key: deviceIdKey)
        return newId
    }
    
    func hasReceivedInitialCredits() -> Bool {
        let deviceId = getOrCreateDeviceId()
        if let initializedDevices = KeychainHelper.load(key: guestCreditsInitializedKey) as? [String] {
            return initializedDevices.contains(deviceId)
        }
        return false
    }
    
    func markInitialCreditsReceived() {
        let deviceId = getOrCreateDeviceId()
        
        if var initializedDevices = KeychainHelper.load(key: guestCreditsInitializedKey) as? [String] {
            if !initializedDevices.contains(deviceId) {
                initializedDevices.append(deviceId)
                KeychainHelper.save(initializedDevices, key: guestCreditsInitializedKey)
            }
        } else {
            KeychainHelper.save([deviceId], key: guestCreditsInitializedKey)
        }
    }
} 
