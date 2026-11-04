import Foundation

public struct QuotaResponse: Codable, Sendable {
    /// 預設帳號的固定標籤。schema v2 起保證每個 provider 至少有一個帳號，且 `main` 排在最前。
    public static let defaultAccount = "main"

    public let schemaVersion: Int
    public let generatedAt: Date
    /// schema v2 起每個 provider 是「一帳號一元素」的陣列。
    ///
    /// 以字典而非固定三鍵結構承接：`agy` 本來就可能整個缺席，
    /// 之後多一個 provider key 也只會被忽略，不會讓整份快照解碼失敗。
    public let providers: [String: [ProviderQuota]]

    public init(schemaVersion: Int, generatedAt: Date, providers: [String: [ProviderQuota]]) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.providers = providers
    }
}

public extension QuotaResponse {
    /// 某個 provider 的所有帳號，依伺服器給的順序。provider 缺席時回傳空陣列。
    func accounts(of provider: String) -> [ProviderQuota] {
        providers[provider] ?? []
    }

    /// 某個 provider 的預設帳號。
    ///
    /// 伺服器承諾 `main` 排在陣列最前，但 schema 文件明確要求以 `account` 比對而非依賴索引，
    /// 因此先找 `main`，找不到才退回第一個元素。
    func primaryAccount(of provider: String) -> ProviderQuota? {
        let accounts = accounts(of: provider)
        return accounts.first { $0.account == Self.defaultAccount } ?? accounts.first
    }
}

public struct ProviderQuota: Codable, Sendable {
    public let provider: String
    /// schema v2 新增。同一個 provider 內唯一，預設帳號固定叫 `main`。
    public let account: String
    public let status: String
    /// schema v2 起可能為 null。
    public let lastSuccessAt: Date?
    public let windows: QuotaWindows
    public let resetCredits: ResetCredits?

    public init(
        provider: String,
        account: String = QuotaResponse.defaultAccount,
        status: String,
        lastSuccessAt: Date?,
        windows: QuotaWindows,
        resetCredits: ResetCredits? = nil
    ) {
        self.provider = provider
        self.account = account
        self.status = status
        self.lastSuccessAt = lastSuccessAt
        self.windows = windows
        self.resetCredits = resetCredits
    }
}

/// 重置券。collector 端的 `applicableAvailableCount` 語意未定，先不解碼也不顯示。
public struct ResetCredits: Codable, Sendable {
    public let availableCount: Int
    public let credits: [ResetCredit]

    public init(availableCount: Int, credits: [ResetCredit]) {
        self.availableCount = availableCount
        self.credits = credits
    }
}

public struct ResetCredit: Codable, Sendable {
    public let status: String
    public let grantedAt: Date
    public let expiresAt: Date?

    public init(status: String, grantedAt: Date, expiresAt: Date?) {
        self.status = status
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
    }
}

/// schema v3 起每個期間是「群組 key → 額度」。Codex／Claude 的帳號整體額度在 `all`；
/// AGY 沒有 `all`，分成 `gemini`、`claude_gpt` 等群組。群組會動態增加，不寫死。
/// 值為 nil 是上游尚無資料，不是剩餘 0%。
public struct QuotaWindows: Codable, Sendable {
    public let fiveHourGroups: [String: UsageWindow?]?
    public let sevenDayGroups: [String: UsageWindow?]?

    enum CodingKeys: String, CodingKey {
        case fiveHourGroups = "five_hour"
        case sevenDayGroups = "seven_day"
    }

    public init(fiveHourGroups: [String: UsageWindow?]?, sevenDayGroups: [String: UsageWindow?]?) {
        self.fiveHourGroups = fiveHourGroups
        self.sevenDayGroups = sevenDayGroups
    }

    /// 只有一個群組時的簡寫，預設放在帳號整體的 `all`。測試與預覽資料大多只需要這種形狀
    public init(fiveHour: UsageWindow?, sevenDay: UsageWindow?, group: String = "all") {
        self.init(fiveHourGroups: [group: fiveHour], sevenDayGroups: [group: sevenDay])
    }
}

/// 視窗另含 `usedPercent`，與 `remainingPercent` 互補，目前不解碼也不顯示。
public struct UsageWindow: Codable, Sendable {
    public let remainingPercent: Double
    public let resetsAt: Date?
    /// 上游有提供才有，例如 "Claude and GPT models"
    public let displayName: String?

    public init(remainingPercent: Double, resetsAt: Date?, displayName: String? = nil) {
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
        self.displayName = displayName
    }
}

public extension ProviderQuota {
    /// 卡片收合時與 Widget 看的群組：Codex／Claude 是帳號整體的 `all`；
    /// AGY 沒有 `all`，平常看 Gemini。與 macOS 端一致
    var primaryGroup: String { provider == "agy" ? "gemini" : "all" }

    /// 展開時列出的群組：兩個期間的聯集，`primaryGroup` 在最前，其餘依 key 排序
    var groups: [String] {
        let keys = Set((windows.fiveHourGroups ?? [:]).keys).union((windows.sevenDayGroups ?? [:]).keys)
        return [primaryGroup] + keys.subtracting([primaryGroup]).sorted()
    }

    /// 不給群組就取 `primaryGroup`。群組不存在或為 null 都回 nil，畫面顯示「—」
    func fiveHour(_ group: String? = nil) -> UsageWindow? {
        windows.fiveHourGroups?[group ?? primaryGroup] ?? nil
    }

    func sevenDay(_ group: String? = nil) -> UsageWindow? {
        windows.sevenDayGroups?[group ?? primaryGroup] ?? nil
    }
}

// MARK: - Date Decoding Strategy

public extension JSONDecoder.DateDecodingStrategy {
    static let customISO8601 = custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateStr = try container.decode(String.self)

        let formatters = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ssX",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        ].map { pattern -> DateFormatter in
            let formatter = DateFormatter()
            formatter.dateFormat = pattern
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            return formatter
        }

        for formatter in formatters {
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "無法解析 ISO 8601 日期字串: \(dateStr)"
        )
    }
}
