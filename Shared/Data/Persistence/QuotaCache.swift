import Foundation

// MARK: - CachedQuota

/// 快取結構：包含最後一次成功取得的 quota 資料及裝置取得時間。
public struct CachedQuota: Codable, Sendable {
    public let quota: QuotaResponse
    public let fetchedAt: Date
    
    public init(quota: QuotaResponse, fetchedAt: Date) {
        self.quota = quota
        self.fetchedAt = fetchedAt
    }
}

// MARK: - QuotaCache

/// 管理 App Group shared container 中的 quota 快取。
/// 主 App 與 Widget Extension 透過此類別共享最後成功資料。
///
/// 設計原則：
/// - 只有驗證成功的遠端資料才能覆寫快取
/// - 寫檔採原子替換，避免 Widget 讀到半份資料
/// - 讀取損壞快取時視為無快取，不 crash
/// - endpoint 變更成功後清除舊快取
public struct QuotaCache: Sendable {
    
    private let containerURL: URL?
    
    public init(containerURL: URL? = nil) {
        if let containerURL {
            self.containerURL = containerURL
        } else {
            self.containerURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: AppGroupConstants.appGroupID)
        }
    }
    
    // MARK: - 快取檔路徑
    
    private var cacheFileURL: URL? {
        containerURL?.appendingPathComponent(AppGroupConstants.cacheFileName)
    }
    
    // MARK: - 讀取
    
    /// 安全讀取快取。損壞或不相容的檔案視為無快取，不 crash。
    public func load() -> CachedQuota? {
        guard let fileURL = cacheFileURL else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .customISO8601
            let cached = try decoder.decode(CachedQuota.self, from: data)
            return cached
        } catch {
            // 損壞或不相容快取視為不存在
            return nil
        }
    }
    
    // MARK: - 寫入
    
    /// 原子寫入快取到 App Group shared container。
    /// 使用原子替換確保 Widget Extension 不會讀到半份資料。
    public func save(_ cached: CachedQuota) throws {
        guard let fileURL = cacheFileURL else { return }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        
        let data = try encoder.encode(cached)
        
        // 原子寫入：先寫臨時檔再替換
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
    
    // MARK: - 清除
    
    /// 清除快取檔案。endpoint 變更時呼叫，避免顯示另一來源的舊資料。
    public func clear() {
        guard let fileURL = cacheFileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
