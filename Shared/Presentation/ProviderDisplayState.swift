import Foundation

public enum ProviderStatus: Sendable, Equatable {
    case ok
    case unknown(String)
    
    public var displayText: String {
        switch self {
        case .ok: return "正常"
        case .unknown(let val): return val
        }
    }
    
    public var isNormal: Bool {
        switch self {
        case .ok: return true
        default: return false
        }
    }
}

public enum SemanticColor: Sendable {
    case green
    case orange
    case red
    case gray
}

public struct WindowDisplayState: Sendable, Equatable {
    public let remainingPercent: Double? // 0...100，或 nil 表示缺值
    public let resetsAt: Date?
    
    public var percentText: String {
        guard let pct = remainingPercent else { return "—" }
        return String(format: "%.0f%%", pct)
    }
    
    public var resetsAtText: String {
        guard let date = resetsAt else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    public var resetsAtVoiceOverText: String {
        guard resetsAt != nil else { return "沒有資料" }
        return resetsAtText
    }
    
    public var percentVoiceOverText: String {
        guard let pct = remainingPercent else { return "沒有資料" }
        return String(format: "百分之 %.0f", pct)
    }
}

public struct ProviderDisplayState: Sendable, Identifiable, Equatable {
    public let id: String // "codex", "claude", "agy"
    public let displayName: String // "Codex", "Claude", "AGY"
    public let status: ProviderStatus
    public let lastSuccessAt: Date?
    public let fiveHour: WindowDisplayState
    public let sevenDay: WindowDisplayState
    
    public init(
        id: String,
        displayName: String,
        status: ProviderStatus,
        lastSuccessAt: Date?,
        fiveHour: WindowDisplayState,
        sevenDay: WindowDisplayState
    ) {
        self.id = id
        self.displayName = displayName
        self.status = status
        self.lastSuccessAt = lastSuccessAt
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }
}
