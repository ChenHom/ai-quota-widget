import SwiftUI

public struct ProgressRingView: View {
    public let progress: Double // 0.0 ~ 1.0
    public let color: Color
    public let ringWidth: CGFloat
    
    public init(progress: Double, color: Color = .blue, ringWidth: CGFloat = 8) {
        self.progress = min(1.0, max(0.0, progress))
        self.color = color
        self.ringWidth = ringWidth
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.12), lineWidth: ringWidth)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(progress))
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [color, color.opacity(0.7)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: -90))
        }
    }
}

#Preview {
    ProgressRingView(progress: 0.75, color: .orange, ringWidth: 10)
        .frame(width: 100, height: 100)
        .padding()
}
