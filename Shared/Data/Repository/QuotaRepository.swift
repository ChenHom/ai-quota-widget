import Foundation

// MARK: - QuotaLoadResult

/// Repository 回傳的統一結果型別。
/// App 與 Widget 不自行決定 fallback 邏輯，一律透過 Repository 取得結果。
public enum QuotaLoadResult: Sendable {
    /// 遠端取得並驗證成功的新資料
    case fresh(CachedQuota)
    /// 遠端失敗但有快取可用，附帶失敗原因
    case cached(CachedQuota, reason: QuotaLoadFailure)
    /// 遠端失敗且無快取
    case unavailable(QuotaLoadFailure)
}

/// 描述載入失敗的原因
public enum QuotaLoadFailure: Sendable {
    case endpointNotConfigured
    case networkError(QuotaError)
}

// MARK: - QuotaRepositoryProtocol

/// Repository 的抽象介面，供測試注入 mock。
public protocol QuotaRepositoryProtocol: Sendable {
    func latestQuota() async -> QuotaLoadResult
    func cachedQuota() -> CachedQuota?
}

// MARK: - QuotaRepository

/// 統一遠端與快取策略的 Repository。
///
/// 流程：
/// 1. 讀取 endpoint
/// 2. endpoint 缺失時直接讀快取
/// 3. 嘗試下載並驗證遠端資料
/// 4. 成功時寫入快取並回傳 .fresh
/// 5. 失敗且有快取時回傳 .cached
/// 6. 失敗且無快取時回傳 .unavailable
public final class QuotaRepository: QuotaRepositoryProtocol, @unchecked Sendable {
    
    private let fetcher: QuotaFetching
    private let cache: QuotaCache
    private let endpointStore: EndpointStore
    
    /// 用來防止同 process 內重複等價刷新的 actor
    private let guard_ = RefreshGuard()
    
    public init(
        fetcher: QuotaFetching = QuotaAPIClient(),
        cache: QuotaCache = QuotaCache(),
        endpointStore: EndpointStore = EndpointStore()
    ) {
        self.fetcher = fetcher
        self.cache = cache
        self.endpointStore = endpointStore
    }
    
    public func latestQuota() async -> QuotaLoadResult {
        return await guard_.execute {
            await self._latestQuota()
        }
    }
    
    private func _latestQuota() async -> QuotaLoadResult {
        // 1. 讀取 endpoint
        guard let endpoint = endpointStore.loadEndpoint() else {
            // endpoint 缺失但快取存在時回傳 cached
            if let cached = cache.load() {
                return .cached(cached, reason: .endpointNotConfigured)
            }
            return .unavailable(.endpointNotConfigured)
        }
        
        // 2. 嘗試遠端取得
        do {
            let response = try await fetcher.fetchQuota(from: endpoint)
            let now = Date()
            let cached = CachedQuota(quota: response, fetchedAt: now)
            
            // 3. 寫入快取
            try? cache.save(cached)
            
            return .fresh(cached)
        } catch {
            let quotaError: QuotaError
            if let qe = error as? QuotaError {
                quotaError = qe
            } else {
                quotaError = .transport(error)
            }
            
            // 4. 失敗時嘗試讀取快取
            if let cached = cache.load() {
                return .cached(cached, reason: .networkError(quotaError))
            }
            
            return .unavailable(.networkError(quotaError))
        }
    }
    
    public func cachedQuota() -> CachedQuota? {
        cache.load()
    }
    
    /// 清除快取（endpoint 變更時呼叫）
    public func clearCache() {
        cache.clear()
    }
}

// MARK: - RefreshGuard

/// 防止同 process 內重複等價刷新。
/// 如果已有一個正在進行的刷新任務，後續呼叫會共用相同的結果。
private actor RefreshGuard {
    private var inFlightTask: Task<QuotaLoadResult, Never>?
    
    func execute(_ operation: @Sendable @escaping () async -> QuotaLoadResult) async -> QuotaLoadResult {
        // 如果已經有任務在跑，直接等待它的結果
        if let existing = inFlightTask {
            return await existing.value
        }
        
        let task = Task {
            await operation()
        }
        inFlightTask = task
        
        let result = await task.value
        inFlightTask = nil
        return result
    }
}
