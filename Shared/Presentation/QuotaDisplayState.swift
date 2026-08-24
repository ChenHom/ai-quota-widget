import Foundation

public struct QuotaDisplayState: Sendable, Equatable {
    public let providers: [ProviderDisplayState]
    public let freshness: FreshnessState
    public let generatedAt: Date?
    public let fetchedAt: Date?
    
    public init(
        providers: [ProviderDisplayState],
        freshness: FreshnessState,
        generatedAt: Date?,
        fetchedAt: Date?
    ) {
        self.providers = providers
        self.freshness = freshness
        self.generatedAt = generatedAt
        self.fetchedAt = fetchedAt
    }
    
    public var lastSyncText: String {
        guard let fetchedAt = fetchedAt else { return "從未同步" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        return formatter.localizedString(for: fetchedAt, relativeTo: Date())
    }
    
    public var lastSyncTextWithFixedNow: (Date) -> String {
        return { now in
            guard let fetchedAt = self.fetchedAt else { return "從未同步" }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            formatter.locale = Locale(identifier: "zh_Hant_TW")
            return formatter.localizedString(for: fetchedAt, relativeTo: now)
        }
    }
}

// MARK: - Mapping Logic

public extension QuotaDisplayState {
    static func map(
        response: QuotaResponse?,
        fetchedAt: Date?,
        now: Date
    ) -> QuotaDisplayState {
        let freshness = FreshnessPolicy.evaluate(generatedAt: response?.generatedAt, now: now)
        
        let providerKeys = [
            ("codex", "Codex"),
            ("claude", "Claude"),
            ("agy", "AGY")
        ]
        
        let providerStates = providerKeys.map { id, displayName -> ProviderDisplayState in
            if let response = response, let providerData = response.providers[id] {
                let statusVal = providerData.status
                let status: ProviderStatus = (statusVal == "ok") ? .ok : .unknown(statusVal)
                
                let fiveHourState = mapWindow(providerData.windows.fiveHour)
                let sevenDayState = mapWindow(providerData.windows.sevenDay)
                
                return ProviderDisplayState(
                    id: id,
                    displayName: displayName,
                    status: status,
                    lastSuccessAt: providerData.lastSuccessAt,
                    fiveHour: fiveHourState,
                    sevenDay: sevenDayState,
                    resetCredits: mapResetCredits(providerData.resetCredits)
                )
            } else {
                // 缺少 Provider 時顯示佔位符
                return ProviderDisplayState(
                    id: id,
                    displayName: displayName,
                    status: .unknown("沒有資料"),
                    lastSuccessAt: nil,
                    fiveHour: WindowDisplayState(remainingPercent: nil, resetsAt: nil),
                    sevenDay: WindowDisplayState(remainingPercent: nil, resetsAt: nil)
                )
            }
        }
        
        return QuotaDisplayState(
            providers: providerStates,
            freshness: freshness,
            generatedAt: response?.generatedAt,
            fetchedAt: fetchedAt
        )
    }
    
    private static func mapResetCredits(_ resetCredits: ResetCredits?) -> ResetCreditsDisplayState? {
        guard let resetCredits, resetCredits.availableCount > 0 else { return nil }
        return ResetCreditsDisplayState(
            availableCount: resetCredits.availableCount,
            expiresAt: resetCredits.credits.map(\.expiresAt)
        )
    }
    
    private static func mapWindow(_ window: UsageWindow?) -> WindowDisplayState {
        guard let window = window else {
            return WindowDisplayState(remainingPercent: nil, resetsAt: nil)
        }
        let percent = min(100.0, max(0.0, window.remainingPercent))
        return WindowDisplayState(remainingPercent: percent, resetsAt: window.resetsAt)
    }
}
