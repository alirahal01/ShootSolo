import SwiftUI
import GoogleMobileAds

@main
struct ShootSoloApp: App {
    init() {
        
        // Initialize AdMob
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
        }
    }
}
