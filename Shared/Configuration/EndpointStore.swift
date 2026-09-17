import Foundation

/// App Group 與 endpoint 相關常數的集中定義。
/// App 與 Widget Extension 必須使用相同的 App Group ID 與 key。
public enum AppGroupConstants {
    public static let appGroupID = "group.com.hom.AIQuota"
    public static let endpointKey = "ai_quota_endpoint_url"
    public static let cacheFileName = "cached_quota.json"
}

/// 建置識別。
///
/// commit SHA 由 build 指令以 `INFOPLIST_KEY_AIQuotaCommit=$(git rev-parse --short HEAD)`
/// 寫進產生的 Info.plist（見 `scripts/redeploy.sh`）。直接在 Xcode 按 Run 不會帶這個設定，
/// 此時顯示「dev」。後綴 `+` 表示 build 當下工作區還有未提交的改動。
public enum AppConfiguration {
    public static let commitLabel: String = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "AIQuotaCommit") as? String,
              !value.trimmingCharacters(in: .whitespaces).isEmpty
        else { return "dev" }
        return value
    }()
}

/// 管理 endpoint 的存取，使用 App Group UserDefaults。
public struct EndpointStore: @unchecked Sendable {
    private let defaults: UserDefaults
    
    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: AppGroupConstants.appGroupID) ?? .standard
    }
    
    // MARK: - 讀取
    
    /// 讀取已保存的 endpoint URL。
    public func loadEndpoint() -> URL? {
        guard let str = defaults.string(forKey: AppGroupConstants.endpointKey),
              let url = URL(string: str) else {
            return nil
        }
        return url
    }
    
    // MARK: - 驗證與儲存
    
    /// 驗證 endpoint 是否為有效的 HTTPS URL（含非空 host），通過後儲存。
    /// - Returns: 驗證通過的 URL，若驗證失敗則回傳 nil。
    @discardableResult
    public func saveEndpoint(_ urlString: String) -> URL? {
        guard let url = validateEndpoint(urlString) else {
            return nil
        }
        defaults.set(urlString, forKey: AppGroupConstants.endpointKey)
        return url
    }
    
    /// 清除已保存的 endpoint。
    public func clearEndpoint() {
        defaults.removeObject(forKey: AppGroupConstants.endpointKey)
    }
    
    /// 驗證 endpoint 格式（不儲存）。
    public func validateEndpoint(_ urlString: String) -> URL? {
        guard let url = URL(string: urlString),
              url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty else {
            return nil
        }
        return url
    }
    
    /// 取得適合顯示於 UI 的 endpoint 摘要（隱藏 query/fragment）。
    /// 規格要求：UI 與一般 log 不應顯示 query、fragment 或可能包含秘密的完整 URL。
    public func displayableEndpoint(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        guard let sanitized = components?.url else {
            return "(未設定)"
        }
        return sanitized.absoluteString
    }
}
