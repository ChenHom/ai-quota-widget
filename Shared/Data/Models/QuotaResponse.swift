import Foundation

public struct QuotaResponse: Codable, Sendable {
    /// 預設帳號的固定標籤。schema v2 保證每個 provider 至少有一個帳號，且 `main` 排在最前。
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

public struct QuotaWindows: Codable, Sendable {
    public let fiveHour: UsageWindow?
    public let sevenDay: UsageWindow?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }

    public init(fiveHour: UsageWindow?, sevenDay: UsageWindow?) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }
}

/// schema v2 的視窗另含 `usedPercent`，與 `remainingPercent` 互補，目前不解碼也不顯示。
public struct UsageWindow: Codable, Sendable {
    public let remainingPercent: Double
    public let resetsAt: Date?

    public init(remainingPercent: Double, resetsAt: Date?) {
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
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
