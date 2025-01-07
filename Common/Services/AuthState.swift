import Foundation
import Combine

class AuthState: ObservableObject {
    @Published var isLoggedIn: Bool = false
} 