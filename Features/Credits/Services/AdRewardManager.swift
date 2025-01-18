//import GoogleMobileAds
//
//class AdRewardManager: NSObject, ObservableObject {
//    static let shared = AdRewardManager()
//    private var rewardedAd: GADRewardedAd?
//    
//    override init() {
//        super.init()
//        loadRewardedAd()
//    }
//    
//    private func loadRewardedAd() {
//        let request = GADRequest()
//        GADRewardedAd.load(withAdUnitID: "YOUR-AD-UNIT-ID",
//                          request: request) { [weak self] ad, error in
//            self?.rewardedAd = ad
//        }
//    }
//    
//    func showAd() async -> Bool {
//        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController,
//              let rewardedAd = rewardedAd else {
//            return false
//        }
//        
//        return await withCheckedContinuation { continuation in
//            rewardedAd.present(fromRootViewController: rootViewController) {
//                continuation.resume(returning: true)
//            }
//        }
//    }
//} 
