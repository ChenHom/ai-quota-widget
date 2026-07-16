import SwiftUI

public extension SemanticColor {
    var color: Color {
        switch self {
        case .green:
            return Color(red: 0.24, green: 0.76, blue: 0.46) // Premium Mint Green
        case .orange:
            return Color(red: 0.98, green: 0.58, blue: 0.20) // Premium Warm Orange
        case .red:
            return Color(red: 0.92, green: 0.34, blue: 0.34) // Soft Crimson Red
        case .gray:
            return Color(.placeholderText)
        }
    }
}
