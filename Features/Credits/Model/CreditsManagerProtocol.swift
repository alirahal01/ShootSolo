import Foundation

protocol CreditsManagerProtocol {
    var creditsBalance: Int { get }
    func addFreeCredits() async
    func addCredits(_ amount: Int) async
} 