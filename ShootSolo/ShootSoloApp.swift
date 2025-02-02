import SwiftUI
import GoogleMobileAds
import Firebase

@main
struct ShootSoloApp: App {
    @StateObject private var authState = AuthState.shared
    
    init() {
        // Configure Firebase first
        FirebaseApp.configure()
        
        // Then initialize AdMob
        GADMobileAds.sharedInstance().start { status in
            print("AdMob initialization status: \(status.adapterStatusesByClassName)")
            print("🚀 Your test device ID: \(GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers?.description ?? "Unknown")")
            // Configure test devices (optional)
            #if DEBUG
            GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = [
                "78133A43-49EB-41E7-9DB4-5C00B2CEC8A6" // Simulator
            ]
            #endif
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authState)
        }
    }
}
