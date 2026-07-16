import Foundation

public enum FreshnessState: String, Sendable, CaseIterable {
    case fresh
    case delayed
    case stale
    case unavailable
    
    public var displayText: String {
        switch self {
        case .fresh: return "資料已同步"
        case .delayed: return "同步有延遲"
        case .stale: return "資料已過期"
        case .unavailable: return "無資料"
        }
    }
}

public struct FreshnessPolicy {
    public static func evaluate(generatedAt: Date?, now: Date) -> FreshnessState {
        guard let generatedAt = generatedAt else {
            return .unavailable
        }
        
        let interval = now.timeIntervalSince(generatedAt)
        let ageInSeconds = max(0, interval) // 未來時間限制年齡為 0
        let ageInMinutes = ageInSeconds / 60.0
        
        if ageInMinutes < 15 {
            return .fresh
        } else if ageInMinutes < 60 {
            return .delayed
        } else {
            return .stale
        }
    }
}
