import Foundation

public struct QuotaResponse: Codable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let providers: [String: ProviderQuota]
    
    public init(schemaVersion: Int, generatedAt: Date, providers: [String: ProviderQuota]) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.providers = providers
    }
}

public struct ProviderQuota: Codable, Sendable {
    public let provider: String
    public let status: String
    public let lastSuccessAt: Date
    public let windows: QuotaWindows
    public let resetCredits: ResetCredits?
    
    public init(provider: String, status: String, lastSuccessAt: Date, windows: QuotaWindows, resetCredits: ResetCredits? = nil) {
        self.provider = provider
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
