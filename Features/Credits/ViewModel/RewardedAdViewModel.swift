import Foundation
import GoogleMobileAds
import AppTrackingTransparency

class RewardedAdViewModel: NSObject, ObservableObject, GADFullScreenContentDelegate {
    @Published var rewardedAd: GADRewardedAd?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    
    private let adUnitID = "ca-app-pub-3940256099942544/1712485313"
    
    override init() {
        super.init()
        #if DEBUG
        print("🎯 Running in DEBUG mode")
        print("🎯 Using test ad unit ID: \(adUnitID)")
        if let deviceId = GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers?.first {
            print("🎯 Test device ID configured: \(deviceId)")
        }
        #endif
        
        // Request tracking authorization after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.requestTracking()
        }
    }
    
    private func requestTracking() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        print("📱 Tracking authorization granted")
                    case .denied:
                        print("📱 Tracking authorization denied")
                    case .restricted:
                        print("📱 Tracking authorization restricted")
                    case .notDetermined:
                        print("📱 Tracking authorization not determined")
                    @unknown default:
                        print("📱 Unknown tracking authorization status")
                    }
                    // Load ad after tracking authorization response
                    self?.loadAd()
                }
            }
        } else {
            // For iOS 13 and below, load ad directly
            loadAd()
        }
    }
    
    func loadAd() {
        print("📢 Starting to load ad")
        guard !isLoading else {
            print("📢 Already loading, skipping")
            return
        }
        
        isLoading = true
        error = nil
        
        let request = GADRequest()
        print("📢 Creating GADRequest")
        
        GADRewardedAd.load(withAdUnitID: adUnitID, request: request) { [weak self] ad, error in
            print("📢 Ad load completion called")
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("📢 Ad load error: \(error.localizedDescription)")
                    self?.error = error.localizedDescription
                    return
                }
                
                print("📢 Ad loaded successfully")
                print("📢 Ad details - type: \(type(of: ad))")
                
                self?.error = nil
                self?.rewardedAd = ad
                self?.rewardedAd?.fullScreenContentDelegate = self
                
                // Verify delegate assignment
                if self?.rewardedAd?.fullScreenContentDelegate != nil {
                    print("📢 Delegate successfully assigned")
                } else {
                    print("⚠️ Warning: Delegate not assigned properly")
                }
            }
        }
    }
    
    func showAd(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        print("📢 [AD SHOW] Starting ad presentation process")
        
        guard let rewardedAd = rewardedAd else {
            print("❌ [AD SHOW] No ad available to show")
            error = "No ad available to show"
            completion(false)
            return
        }
        
        // Get the topmost view controller
        let topmostViewController = self.getTopmostViewController(from: viewController)
        print("📢 [AD SHOW] Original ViewController type: \(type(of: viewController))")
        print("📢 [AD SHOW] Topmost ViewController type: \(type(of: topmostViewController))")
        
        // Check window state
        if let window = topmostViewController.view.window {
            print("✅ [AD SHOW] Window exists")
            print("📢 [AD SHOW] Is key window: \(window.isKeyWindow)")
        } else {
            print("⚠️ [AD SHOW] No window found for view controller")
        }
        
        // If there's a presented controller, dismiss it first
        if let presentedVC = topmostViewController.presentedViewController {
            print("⚠️ [AD SHOW] Found presented controller of type: \(type(of: presentedVC))")
            print("📢 [AD SHOW] Dismissing current presentation before showing ad")
            
            topmostViewController.dismiss(animated: true) {
                print("✅ [AD SHOW] Successfully dismissed previous controller")
                self.presentAd(using: rewardedAd, from: topmostViewController, completion: completion)
            }
        } else {
            print("✅ [AD SHOW] No presented controller found, showing ad directly")
            self.presentAd(using: rewardedAd, from: topmostViewController, completion: completion)
        }
    }

    private func presentAd(using ad: GADRewardedAd, from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        print("📢 [AD PRESENT] Attempting to present ad")
        print("📢 [AD PRESENT] Presenting from VC type: \(type(of: viewController))")
        
        ad.present(fromRootViewController: viewController) { [weak self] in
            print("📢 [AD PRESENT] Ad presentation callback triggered")
            
            if let reward = self?.rewardedAd?.adReward {
                print("✅ [AD PRESENT] Reward received:")
                print("   - Amount: \(reward.amount)")
                print("   - Type: \(reward.type)")
                completion(true)
            } else {
                print("❌ [AD PRESENT] No reward received")
                self?.error = "Failed to receive reward"
                completion(false)
            }
        }
    }

    private func getTopmostViewController(from controller: UIViewController) -> UIViewController {
        print("📢 [TOPMOST] Starting search from controller type: \(type(of: controller))")
        
        if let presented = controller.presentedViewController {
            print("📢 [TOPMOST] Found presented controller of type: \(type(of: presented))")
            return getTopmostViewController(from: presented)
        }
        
        if let navigationController = controller as? UINavigationController {
            let lastVC = navigationController.viewControllers.last ?? controller
            print("📢 [TOPMOST] Found navigation controller, using last VC of type: \(type(of: lastVC))")
            return lastVC
        }
        
        if let tabController = controller as? UITabBarController,
           let selected = tabController.selectedViewController {
            print("📢 [TOPMOST] Found tab controller, using selected VC of type: \(type(of: selected))")
            return getTopmostViewController(from: selected)
        }
        
        print("📢 [TOPMOST] Using controller as is, type: \(type(of: controller))")
        return controller
    }

    // Add this helper function to inspect view controller hierarchy
    private func logViewControllerHierarchy(from controller: UIViewController, level: Int = 0) {
        let indent = String(repeating: "  ", count: level)
        print("\(indent)📱 [\(type(of: controller))]")
        
        if let presented = controller.presentedViewController {
            print("\(indent)  ├─ Presented:")
            logViewControllerHierarchy(from: presented, level: level + 2)
        }
        
        if let nav = controller as? UINavigationController {
            print("\(indent)  ├─ Navigation Stack:")
            nav.viewControllers.forEach { vc in
                logViewControllerHierarchy(from: vc, level: level + 2)
            }
        }
        
        if let tab = controller as? UITabBarController {
            print("\(indent)  ├─ Tab Controllers:")
            tab.viewControllers?.forEach { vc in
                logViewControllerHierarchy(from: vc, level: level + 2)
            }
        }
    }
    
    // MARK: - GADFullScreenContentDelegate
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("📢 Ad dismissed")
        rewardedAd = nil
        loadAd() // Preload next ad
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("📢 Ad failed to present with error: \(error.localizedDescription)")
        print("📢 Error details: \(error)")
        self.error = error.localizedDescription
        rewardedAd = nil
        isLoading = false
        loadAd() // Try to load another ad
    }
    
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("📢 Ad will present full screen content")
        print("📢 Ad type: \(type(of: ad))")
    }
    
    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        print("📢 Ad did record impression")
    }
    
    // Helper function to get device/environment info
    private func logEnvironmentInfo() {
        print("📱 Device Info:")
        print("   - iOS Version: \(UIDevice.current.systemVersion)")
        print("   - Device Type: \(UIDevice.current.model)")
        print("   - Is Debug: \(isDebug)")
    }
    
    private var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
