import Foundation

/// 狀態文案與 macOS 端（ai-quota 的 QuotaPanel）一致：
/// 只分「正常／資料延遲／暫無資料」三種，不把 collector 的原始 status 值直接顯示給使用者。
/// 原始值保留在 `.delayed` 的關聯值裡供診斷。
public enum ProviderStatus: Sendable, Equatable {
    case ok
    case delayed(String)
    case noData

    public var displayText: String {
        switch self {
        case .ok: return "正常"
        case .delayed: return "資料延遲"
        case .noData: return "暫無資料"
        }
    }

    public var isNormal: Bool {
        switch self {
        case .ok: return true
        default: return false
        }
    }

    public var semanticColor: SemanticColor {
        isNormal ? .green : .orange
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

    /// 卡片上的重置欄位。與 macOS 端一致：有值才加「重置 」前綴，沒有值就整格留白。
    public var resetsAtRowText: String {
        guard resetsAt != nil else { return "" }
        return "重置 \(resetsAtText)"
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

/// 一列 = 一個 provider 的一個帳號。
///
/// schema v2 起同一個 provider 可能有多個帳號，因此 `id` 必須是
/// `provider/account` 複合鍵：兩列共用同一個 id 會讓 `ForEach` 的
/// `Identifiable` 撞號，SwiftUI 不會報錯，只會安靜地畫錯。
public struct ProviderDisplayState: Sendable, Identifiable, Equatable {
    public let id: String // "codex/main", "claude/work"
    public let providerID: String // "codex", "claude", "agy"
    public let displayName: String // "Codex", "Claude", "AGY"
    public let account: String // "main", "work"
    /// 這是該 provider 的第幾個帳號，決定卡片底色；0 為預設帳號、不上色
    public let accountIndex: Int
    /// 該 provider 共有幾個帳號。為 1 時完全不顯示帳號標籤，外觀與單帳號時相同
    public let accountCount: Int
    public let status: ProviderStatus
    public let lastSuccessAt: Date?
    public let fiveHour: WindowDisplayState
    public let sevenDay: WindowDisplayState
    public let resetCredits: ResetCreditsDisplayState?

    public init(
        providerID: String,
        displayName: String,
        account: String = QuotaResponse.defaultAccount,
        accountIndex: Int = 0,
        accountCount: Int = 1,
        status: ProviderStatus,
        lastSuccessAt: Date?,
        fiveHour: WindowDisplayState,
        sevenDay: WindowDisplayState,
        resetCredits: ResetCreditsDisplayState? = nil
    ) {
        self.id = "\(providerID)/\(account)"
        self.providerID = providerID
        self.displayName = displayName
        self.account = account
        self.accountIndex = accountIndex
        self.accountCount = accountCount
        self.status = status
        self.lastSuccessAt = lastSuccessAt
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.resetCredits = resetCredits
    }

    /// 是否為預設帳號。Widget 目前只顯示預設帳號，維持固定三列版面。
    public var isDefaultAccount: Bool { account == QuotaResponse.defaultAccount }

    /// 非預設帳號才顯示的標籤。預設帳號沿用 provider 原名、不加後綴，與 macOS 端一致 —
    /// 疊牌一次只看得到一張卡，哪一張是 main 由指示點與底色交代，不需要再掛一個標籤。
    public var accountLabel: String? {
        (accountCount > 1 && !isDefaultAccount) ? account : nil
    }

    /// 卡片上的 provider 最後成功時間，只到分鐘。與 macOS 端一致。
    public var lastSuccessTimeText: String {
        guard let lastSuccessAt else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: lastSuccessAt)
    }

    public var voiceOverLabel: String {
        let name = accountLabel.map { "\(displayName) \($0)" } ?? displayName
        return "\(name)，\(status.displayText)，"
            + "5小時額度\(fiveHour.percentVoiceOverText)，"
            + "7天額度\(sevenDay.percentVoiceOverText)。"
    }
}

/// 一個 provider 的一落牌。多帳號時卡片疊在同一個位置，按一下把最前面那張壓下去，
/// 彈回來時已經換成下一個帳號；單帳號時退化成一張普通卡片。
///
/// 排序與選取邏輯與 macOS 端的 `ProviderStack` 相同：一律以 `account` 比對而非索引，
/// 因為伺服器每次快照都可能重排陣列，使用者看的必須還是同一個帳號。
public struct ProviderStackDisplayState: Sendable, Identifiable, Equatable {
    public let id: String // providerID
    public let displayName: String
    public let accounts: [ProviderDisplayState]
    
    public init(id: String, displayName: String, accounts: [ProviderDisplayState]) {
        self.id = id
        self.displayName = displayName
        self.accounts = accounts
    }
    
    public var isMultiAccount: Bool { accounts.count > 1 }
    
    /// 以 `frontAccount` 為首的循環排列。
    /// 帳號不存在（快照換過、該帳號已移除）時退回原順序，也就是 `main` 在最前。
    public func ordered(from frontAccount: String?) -> [ProviderDisplayState] {
        guard isMultiAccount,
              let frontAccount,
              let start = accounts.firstIndex(where: { $0.account == frontAccount })
        else { return accounts }
        return Array(accounts[start...]) + Array(accounts[..<start])
    }
    
    /// 按一下之後要切到的下一個帳號；單帳號時為 nil。
    public func account(after frontAccount: String?) -> String? {
        let order = ordered(from: frontAccount)
        guard order.count > 1 else { return nil }
        return order[1].account
    }
    
    /// `frontAccount` 在 `accounts` 裡的位置，供指示點標示現在看第幾張。
    public func index(of frontAccount: String?) -> Int {
        guard let frontAccount,
              let index = accounts.firstIndex(where: { $0.account == frontAccount })
        else { return 0 }
        return index
    }
}
