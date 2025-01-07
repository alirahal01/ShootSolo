import SwiftUI

struct ZoomControlView: View {
    @Binding var zoomFactor: CGFloat
    let zoomLevels: [CGFloat] = [0.5, 1.0, 3.0]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(zoomLevels, id: \.self) { level in
                Button(action: {
                    withAnimation {
                        zoomFactor = level
                    }
                }) {
                    Text("\(level, specifier: "%.1f")x")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: zoomFactor == level ? 45 : 35, height: zoomFactor == level ? 45 : 35)
                        .background(zoomFactor == level ? Color.white : Color.black)
                        .foregroundColor(zoomFactor == level ? Color.black : Color.white)
                        .clipShape(Circle())
                        .animation(.easeInOut(duration: 0.2), value: zoomFactor)
                }
            }
        }
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.3))
        .cornerRadius(20)
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