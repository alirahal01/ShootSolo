import Foundation
import GoogleMobileAds
import AppTrackingTransparency

class RewardedAdViewModel: NSObject, ObservableObject, GADFullScreenContentDelegate {
    @Published var rewardedAd: GADRewardedAd?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var lastFailureReason: AdLoadFailureReason = .none
    
    private let adUnitID: String = "ca-app-pub-3372761633164622/5636738003"
    private var nextAd: GADRewardedAd?
    
    // Singleton instance for preloading
    static let shared = RewardedAdViewModel()
    
    enum AdLoadFailureReason {
        case none
        case noConnection
        case timeout
        case noInventory
        case rateLimit
        case configuration
        case other(String)
        
        var userMessage: String {
            switch self {
            case .none:
                return ""
            case .noConnection:
                return "No internet connection. Please check your connection and try again."
            case .timeout:
                return "Request timed out. Please try again."
            case .noInventory:
                return "No ads available right now. Please try again later."
            case .rateLimit:
                return "Too many requests. Please wait a moment."
            case .configuration:
                return "Ad configuration error. Please try again later."
            case .other(let message):
                return message
            }
        }
    }
    
    override init() {
        super.init()
        
        // Start loading immediately on init
        GADMobileAds.sharedInstance().start { [weak self] status in
            print("📢 AdMob SDK initialization complete: \(status.description)")
            // Start loading both current and next ad
            self?.preloadAds()
        }
    }
    
    private func preloadAds() {
        // Load both current and next ad
        loadAd()
        loadNextAd()
    }
    
    private func loadNextAd() {
        let request = GADRequest()
        
        GADRewardedAd.load(withAdUnitID: adUnitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("📢 Failed to load next ad: \(error.localizedDescription)")
                    return
                }
                
                self?.nextAd = ad
                self?.nextAd?.fullScreenContentDelegate = self
                print("📢 Next ad successfully preloaded")
            }
        }
    }
    
    func loadAd() {
        guard !isLoading, rewardedAd == nil else { return }
        
        guard NetworkMonitor.shared.isConnected else {
            self.lastFailureReason = .noConnection
            return
        }
        
        isLoading = true
        error = nil
        lastFailureReason = .none
        
        let request = GADRequest()
        
        // Add timeout
        let timeout = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                if self?.isLoading == true {
                    self?.isLoading = false
                    self?.lastFailureReason = .timeout
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeout)
        
        GADRewardedAd.load(withAdUnitID: adUnitID, request: request) { [weak self] ad, error in
            timeout.cancel()
            
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("📢 Failed to load ad: \(error.localizedDescription)")
                    
                    // Categorize the error based on error description since GADRequestError is not available
                    let errorDescription = error.localizedDescription.lowercased()
                    if errorDescription.contains("no fill") {
                        self?.lastFailureReason = .noInventory
                    } else if errorDescription.contains("network") {
                        self?.lastFailureReason = .noConnection
                    } else if errorDescription.contains("invalid") {
                        self?.lastFailureReason = .configuration
                    } else {
                        self?.lastFailureReason = .other(error.localizedDescription)
                    }
                    
                    // Retry with exponential backoff
                    self?.scheduleRetry()
                    return
                }
                
                self?.error = nil
                self?.lastFailureReason = .none
                self?.rewardedAd = ad
                self?.rewardedAd?.fullScreenContentDelegate = self
                print("📢 Ad successfully preloaded")
            }
        }
    }
    
    private var retryCount = 0
    private let maxRetries = 3
    
    private func scheduleRetry() {
        guard retryCount < maxRetries else {
            retryCount = 0
            return
        }
        
        let delay = pow(2.0, Double(retryCount)) // Exponential backoff: 2, 4, 8 seconds
        retryCount += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.loadAd()
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
        
        let topmostViewController = self.getTopmostViewController(from: viewController)
        
        rewardedAd.present(fromRootViewController: topmostViewController) { [weak self] in
            print("✅ [AD SHOW] Ad presented successfully")
            
            // Move next ad to current if available
            if let nextAd = self?.nextAd {
                self?.rewardedAd = nextAd
                self?.nextAd = nil
                // Start loading new next ad
                self?.loadNextAd()
            } else {
                // If no next ad, clear current and start loading new one
                self?.rewardedAd = nil
                self?.loadAd()
            }
            
            completion(true)
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
        
        // If we don't have a next ad ready, start loading one
        if nextAd == nil && rewardedAd == nil {
            loadAd()
        }
        
        // Always ensure we're loading the next ad
        if nextAd == nil {
            loadNextAd()
        }
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
