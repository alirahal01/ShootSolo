import SwiftUI

struct ModalTrackingModifier: ViewModifier {
    @Binding var isModalPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                isModalPresented = true
            }
            .onDisappear {
                isModalPresented = false
            }
    }
}

extension View {
    func trackModalPresentation(isPresented: Binding<Bool>) -> some View {
        self.modifier(ModalTrackingModifier(isModalPresented: isPresented))
    }
} 