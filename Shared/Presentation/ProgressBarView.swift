import SwiftUI

public struct ProgressBarView: View {
    public let progress: Double // 0.0 ~ 1.0
    public let color: Color
    public let height: CGFloat
    
    public init(progress: Double, color: Color = .blue, height: CGFloat = 6) {
        self.progress = min(1.0, max(0.0, progress))
        self.color = color
        self.height = height
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.12))
                    .frame(height: height)
                
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color, color.opacity(0.75)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: CGFloat(progress) * geometry.size.width, height: height)
            }
        }
        .frame(height: height)
    }
}

#Preview {
    ProgressBarView(progress: 0.6, color: .green)
        .padding()
}
