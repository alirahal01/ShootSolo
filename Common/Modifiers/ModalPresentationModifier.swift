import SwiftUI

struct ModalPresentationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .withNetworkStatusOverlay()
    }
}

extension View {
    func withModalPresentation() -> some View {
        self.modifier(ModalPresentationModifier())
    }
} 