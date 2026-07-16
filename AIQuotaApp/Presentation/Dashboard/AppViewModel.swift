import Foundation
import Observation
import WidgetKit

@Observable
public final class AppViewModel {
    public var displayState: QuotaDisplayState
    public var isLoading: Bool = false
    public var errorMessage: String? = nil
    public var endpoint: String = ""
    public var hasEndpoint: Bool = false
    
    private let repository: QuotaRepository
    private let endpointStore: EndpointStore
    private let cache: QuotaCache
    
    /// 追蹤上一次的 displayState，用來決定是否需要 reload Widget timeline
    private var previousDisplayState: QuotaDisplayState?
    
    public init(
        repository: QuotaRepository = QuotaRepository(),
        endpointStore: EndpointStore = EndpointStore(),
        cache: QuotaCache = QuotaCache()
    ) {
        self.repository = repository
        self.endpointStore = endpointStore
        self.cache = cache
        self.displayState = QuotaDisplayState.map(response: nil, fetchedAt: nil, now: Date())
        self.loadSavedEndpoint()
    }
    
    // MARK: - 載入已儲存的設定
    
    public func loadSavedEndpoint() {
        if let url = endpointStore.loadEndpoint() {
            self.endpoint = url.absoluteString
            self.hasEndpoint = true
            // 嘗試讀取快取以立即顯示
            if let cached = cache.load() {
                let now = Date()
                self.displayState = QuotaDisplayState.map(
                    response: cached.quota,
                    fetchedAt: cached.fetchedAt,
                    now: now
                )
            }
        } else {
            self.endpoint = ""
            self.hasEndpoint = false
        }
    }
    
    // MARK: - 手動重新整理
    
    public func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        let result = await repository.latestQuota()
        applyResult(result)
        
        isLoading = false
    }
    
    // MARK: - 儲存 Endpoint（含連線測試）
    
    public func saveEndpoint(_ urlString: String) async -> Bool {
        // 先驗證格式
        guard endpointStore.validateEndpoint(urlString) != nil else {
            self.errorMessage = QuotaError.invalidEndpoint.errorDescription
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        // 儲存到 App Group UserDefaults
        guard let url = endpointStore.saveEndpoint(urlString) else {
            self.errorMessage = QuotaError.invalidEndpoint.errorDescription
            isLoading = false
            return false
        }
        
        // endpoint 變更後清除舊快取
        repository.clearCache()
        
        // 執行連線測試（直接嘗試取得資料）
        let result = await repository.latestQuota()
        
        switch result {
        case .fresh:
            self.endpoint = url.absoluteString
            self.hasEndpoint = true
            applyResult(result)
            isLoading = false
            return true
            
        case .cached(_, let reason), .unavailable(let reason):
            // 連線測試失敗，恢復舊設定
            endpointStore.clearEndpoint()
            
            switch reason {
            case .endpointNotConfigured:
                self.errorMessage = QuotaError.configurationMissing.errorDescription
            case .networkError(let error):
                self.errorMessage = error.errorDescription
            }
            isLoading = false
            return false
        }
    }
    
    // MARK: - 重設連線
    
    public func resetConnection() {
        endpointStore.clearEndpoint()
        repository.clearCache()
        self.endpoint = ""
        self.hasEndpoint = false
        self.displayState = QuotaDisplayState.map(response: nil, fetchedAt: nil, now: Date())
        self.errorMessage = nil
        reloadWidgetTimeline()
    }
    
    // MARK: - Mock 場景（僅供開發預覽）
    
    public enum MockScenario {
        case normal, delayed, stale, unavailable
    }
    
    public func loadMockData(_ scenario: MockScenario) {
        let now = Date()
        switch scenario {
        case .normal:
            let resp = MockData.normalQuota
            self.displayState = QuotaDisplayState.map(response: resp, fetchedAt: now, now: now)
            self.errorMessage = nil
        case .delayed:
            let resp = MockData.delayedQuota
            self.displayState = QuotaDisplayState.map(response: resp, fetchedAt: now.addingTimeInterval(-1800), now: now)
            self.errorMessage = nil
        case .stale:
            let resp = MockData.staleQuota
            self.displayState = QuotaDisplayState.map(response: resp, fetchedAt: now.addingTimeInterval(-7200), now: now)
            self.errorMessage = nil
        case .unavailable:
            self.displayState = QuotaDisplayState.map(response: nil, fetchedAt: nil, now: now)
            self.errorMessage = "無法取得資料，請檢查伺服器連線。"
        }
    }
    
    // MARK: - Private
    
    private func applyResult(_ result: QuotaLoadResult) {
        let now = Date()
        
        switch result {
        case .fresh(let cached):
            let newState = QuotaDisplayState.map(
                response: cached.quota,
                fetchedAt: cached.fetchedAt,
                now: now
            )
            // 只有內容實際改變時才 reload Widget
            if previousDisplayState != newState {
                reloadWidgetTimeline()
            }
            previousDisplayState = newState
            self.displayState = newState
            self.errorMessage = nil
            
        case .cached(let cached, let reason):
            self.displayState = QuotaDisplayState.map(
                response: cached.quota,
                fetchedAt: cached.fetchedAt,
                now: now
            )
            // 有快取時使用非阻斷式錯誤
            switch reason {
            case .endpointNotConfigured:
                self.errorMessage = "尚未設定端點，目前顯示的是快取資料。"
            case .networkError(let error):
                self.errorMessage = error.errorDescription
            }
            
        case .unavailable(let reason):
            self.displayState = QuotaDisplayState.map(response: nil, fetchedAt: nil, now: now)
            switch reason {
            case .endpointNotConfigured:
                self.errorMessage = QuotaError.configurationMissing.errorDescription
            case .networkError(let error):
                self.errorMessage = error.errorDescription
            }
        }
    }
    
    private func reloadWidgetTimeline() {
        WidgetCenter.shared.reloadTimelines(ofKind: "AIQuotaWidget")
    }
}
