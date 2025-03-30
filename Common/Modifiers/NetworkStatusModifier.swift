import SwiftUI

struct NetworkStatusModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            content
            NetworkStatusOverlay()
        }
    }
}

extension View {
    func withNetworkStatusOverlay() -> some View {
        self.modifier(NetworkStatusModifier())
    }
} 