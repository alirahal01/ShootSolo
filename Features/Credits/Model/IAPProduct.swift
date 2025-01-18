import Foundation
import StoreKit

enum IAPProduct: String, CaseIterable {
    case credits20 = "com.shootsolo.credits.20"
    case credits100 = "com.shootsolo.credits.100"
    case credits400 = "com.shootsolo.credits.400"
    
    var credits: Int {
        switch self {
        case .credits20: return 20
        case .credits100: return 100
        case .credits400: return 400
        }
    }
    
    var price: Decimal {
        switch self {
        case .credits20: return 1.99
        case .credits100: return 9.99
        case .credits400: return 29.99
        }
    }
}

struct ProductModel: Identifiable {
    let id: String
    let product: Product
    let credits: Int
} 