import SwiftUI
import GoogleMobileAds
import Firebase

@main
struct ShootSoloApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authState = AuthState.shared
    
    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .environmentObject(authState)
                .withNetworkStatusOverlay()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase only if not already configured
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Initialize AdMob asynchronously
        Task {
            GADMobileAds.sharedInstance().start { status in
                print("AdMob initialization status: \(status.adapterStatusesByClassName)")
                #if DEBUG
                GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = [
                    "78133A43-49EB-41E7-9DB4-5C00B2CEC8A6" // Simulator
                ]
                #endif
            }
        }
        
        return true
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // Only allow landscape orientations
        return .portrait
    }
}
