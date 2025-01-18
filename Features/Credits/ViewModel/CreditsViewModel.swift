import Foundation
import Combine

@MainActor
class CreditsViewModel: ObservableObject {
    @Published var credits: Int = 0
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe credits balance changes
        CreditsManager.shared.$creditsBalance
            .receive(on: RunLoop.main)
            .assign(to: &$credits)
    }
    
    func purchaseCredits(amount: Int) async {
        // Implementation will come from CreditsManager
    }
    
    func watchAdForCredits() async {
        await CreditsManager.shared.addFreeCredits()
    }
} 
