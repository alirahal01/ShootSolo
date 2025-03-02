import SwiftUI

struct ZoomControlView: View {
    @Binding var zoomFactor: CGFloat
    let zoomLevels: [CGFloat] = [1.0, 2.0] // Changed from 3.0 to 2.0
    
    // Add a namespace for matched geometry effect
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 10) {
            ForEach(zoomLevels, id: \.self) { level in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        zoomFactor = level
                    }
                }) {
                    Text("\(level, specifier: "%.1f")x")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: zoomFactor == level ? 45 : 35, height: zoomFactor == level ? 45 : 35)
                        .background(
                            Circle()
                                .fill(zoomFactor == level ? Color.white : Color.black)
                                .matchedGeometryEffect(
                                    id: level,
                                    in: animation,
                                    properties: .frame,
                                    isSource: true
                                )
                        )
                        .foregroundColor(zoomFactor == level ? Color.black : Color.white)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 15)
        .background(Color.black.opacity(0.3))
        .cornerRadius(20)
    }
}

// Add a custom button style for better feedback
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ZoomControlView_Previews: PreviewProvider {
    static var previews: some View {
        ZoomControlView(zoomFactor: .constant(1.0))
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.gray)
    }
} 