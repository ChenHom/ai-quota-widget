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

/// 重置券只做摘要：名稱旁一個 `+N` 徽章，點開才列出各張券的到期時間。
/// 逐筆攤開會讓卡片高度隨券數浮動，違背固定版面。
public struct ResetCreditsDisplayState: Sendable, Equatable {
    public let availableCount: Int
    public let expiresAt: [Date?] // 依 JSON 原順序，nil 表示該張券沒有到期時間
    
    public init(availableCount: Int, expiresAt: [Date?]) {
        self.availableCount = availableCount
        self.expiresAt = expiresAt
    }
    
    public var badgeText: String { "+\(availableCount)" }
    
    /// 到期時間固定以 Asia/Taipei 顯示，不隨裝置時區改變（與 collector 端的口徑一致）；
    /// 其餘時間顯示仍沿用裝置時區。
    public var expiryTexts: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        return expiresAt.map { $0.map(formatter.string(from:)) ?? "—" }
    }
}

public struct ProviderDisplayState: Sendable, Identifiable, Equatable {
    public let id: String // "codex", "claude", "agy"
    public let displayName: String // "Codex", "Claude", "AGY"
    public let status: ProviderStatus
    public let lastSuccessAt: Date?
    public let fiveHour: WindowDisplayState
    public let sevenDay: WindowDisplayState
    public let resetCredits: ResetCreditsDisplayState?
    
    public init(
        id: String,
        displayName: String,
        status: ProviderStatus,
        lastSuccessAt: Date?,
        fiveHour: WindowDisplayState,
        sevenDay: WindowDisplayState,
        resetCredits: ResetCreditsDisplayState? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.status = status
        self.lastSuccessAt = lastSuccessAt
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.resetCredits = resetCredits
    }
}
