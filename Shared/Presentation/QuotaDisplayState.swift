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
    
    /// 只含各 provider 預設帳號的列。
    ///
    /// Widget 目前沿用這個維持固定三列版面：`systemMedium` 的垂直空間不夠再多一列，
    /// 多帳號要怎麼在 Widget 呈現尚未定案。App Dashboard 是 ScrollView，沒有這個限制，
    /// 直接用 `providers` 顯示所有帳號。
    public var defaultAccountProviders: [ProviderDisplayState] {
        providers.filter(\.isDefaultAccount)
    }

    /// 面板標頭的「最後同步」時間，只到分鐘。與 macOS 端一致。
    public var lastSyncTimeText: String {
        guard let fetchedAt else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: fetchedAt)
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
        
        // schema v2 起一個 provider 可能有多個帳號（目前 claude 有 main、work），
        // 因此一個帳號展開成一列。Provider 之間維持固定順序，同一個 provider 內
        // 沿用伺服器給的順序（main 保證在最前）。
        let providerStates = providerKeys.flatMap { id, displayName -> [ProviderDisplayState] in
            let accounts = response?.accounts(of: id) ?? []

            // 缺少 Provider 時保留一列佔位符
            guard !accounts.isEmpty else {
                return [
                    ProviderDisplayState(
                        providerID: id,
                        displayName: displayName,
                        status: .noData,
                        lastSuccessAt: nil,
                        fiveHour: WindowDisplayState(remainingPercent: nil, resetsAt: nil),
                        sevenDay: WindowDisplayState(remainingPercent: nil, resetsAt: nil)
                    )
                ]
            }

            return accounts.enumerated().map { index, providerData in
                let statusVal = providerData.status
                let status: ProviderStatus = (statusVal == "ok") ? .ok : .delayed(statusVal)

                return ProviderDisplayState(
                    providerID: id,
                    displayName: displayName,
                    account: providerData.account,
                    accountIndex: index,
                    accountCount: accounts.count,
                    status: status,
                    lastSuccessAt: providerData.lastSuccessAt,
                    fiveHour: mapWindow(providerData.windows.fiveHour),
                    sevenDay: mapWindow(providerData.windows.sevenDay),
                    resetCredits: mapResetCredits(providerData.resetCredits)
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
