import Foundation

protocol CreditsManagerProtocol {
    var creditsBalance: Int { get }
    var userId: String? { get }
    func addFreeCredits() async
    func addCredits(_ amount: Int) async
    func syncCreditsWithFirestore() async throws
} 