import SwiftUI
import WidgetKit

/// Widget 視覺矩陣 Previews
/// 涵蓋 WID-002、WID-003 所有狀態的可重現 preview。
///
/// 使用方式：在 Xcode 中開啟此檔案，選擇 Canvas 即可預覽所有狀態組合。

// MARK: - 正常資料

#Preview("正常 (Fresh)", as: .systemMedium) {
    AIQuotaWidget()
} timeline: {
    QuotaEntry.mockEntry
}

// MARK: - 部分 Window 缺值

#Preview("部分缺值", as: .systemMedium) {
    AIQuotaWidget()
} timeline: {
    {
        let now = Date()
        let response = QuotaResponse(
            schemaVersion: 1,
            generatedAt: now.addingTimeInterval(-300),
            providers: [
                "codex": ProviderQuota(
                    provider: "codex", status: "ok",
                    lastSuccessAt: now.addingTimeInterval(-320),
                    windows: QuotaWindows(
                        fiveHour: UsageWindow(remainingPercent: 82.4, resetsAt: now.addingTimeInterval(3600)),
                        sevenDay: UsageWindow(remainingPercent: 54.0, resetsAt: nil)
                    )
                ),
                "claude": ProviderQuota(
                    provider: "claude", status: "ok",
                    lastSuccessAt: now.addingTimeInterval(-330),
                    windows: QuotaWindows(fiveHour: nil, sevenDay: nil)
                ),
                "agy": ProviderQuota(
                    provider: "agy", status: "ok",
                    lastSuccessAt: now.addingTimeInterval(-340),
                    windows: QuotaWindows(
                        fiveHour: UsageWindow(remainingPercent: 41.0, resetsAt: now.addingTimeInterval(1800)),
                        sevenDay: nil
                    )
                )
            ]
        )
        let state = QuotaDisplayState.map(response: response, fetchedAt: now, now: now)
        return QuotaEntry(date: now, displayState: state)
    }()
}

// MARK: - Provider 缺失 (Claude missing)

#Preview("缺少 Provider", as: .systemMedium) {
    AIQuotaWidget()
} timeline: {
    {
        let now = Date()
        let response = QuotaResponse(
            schemaVersion: 1,
            generatedAt: now.addingTimeInterval(-300),
            providers: [
                "codex": ProviderQuota(
                    provider: "codex", status: "ok",
                    lastSuccessAt: now.addingTimeInterval(-320),
                    windows: QuotaWindows(
                        fiveHour: UsageWindow(remainingPercent: 82.4, resetsAt: nil),
                        sevenDay: UsageWindow(remainingPercent: 54.0, resetsAt: nil)
                    )
                ),
                "agy": ProviderQuota(
                    provider: "agy", status: "ok",
                    lastSuccessAt: now.addingTimeInterval(-340),
                    windows: QuotaWindows(
                        fiveHour: UsageWindow(remainingPercent: 41.0, resetsAt: nil),
                        sevenDay: nil
                    )
                )
            ]
        )
        let state = QuotaDisplayState.map(response: response, fetchedAt: now, now: now)
        return QuotaEntry(date: now, displayState: state)
    }()
}

// MARK: - Delayed (15-60 分鐘)

#Preview("同步延遲 (Delayed)", as: .systemMedium) {
    AIQuotaWidget()
} timeline: {
    QuotaEntry.mockDelayedEntry
}

// MARK: - Stale (> 60 分鐘)

#Preview("資料過期 (Stale)", as: .systemMedium) {
    AIQuotaWidget()
} timeline: {
    QuotaEntry.mockStaleEntry
}

// MARK: - Unavailable (無任何資料)

#Preview("無資料 (Unavailable)", as: .systemMedium) {
    AIQuotaWidget()
} timeline: {
    QuotaEntry.mockEmptyEntry
}

// MARK: - 極低額度 (接近用完)

#Preview("極低額度", as: .systemMedium) {
    AIQuotaWidget()
} timeline: {
    {
        let now = Date()
        let response = QuotaResponse(
            schemaVersion: 1,
            generatedAt: now.addingTimeInterval(-300),
            providers: [
                "codex": ProviderQuota(
                    provider: "codex", status: "rate_limited",
                    lastSuccessAt: now.addingTimeInterval(-600),
                    windows: QuotaWindows(
                        fiveHour: UsageWindow(remainingPercent: 0.0, resetsAt: now.addingTimeInterval(900)),
                        sevenDay: UsageWindow(remainingPercent: 3.0, resetsAt: nil)
                    )
                ),
                "claude": ProviderQuota(
                    provider: "claude", status: "ok",
                    lastSuccessAt: now.addingTimeInterval(-330),
                    windows: QuotaWindows(
                        fiveHour: UsageWindow(remainingPercent: 2.5, resetsAt: now.addingTimeInterval(1200)),
                        sevenDay: UsageWindow(remainingPercent: 8.0, resetsAt: nil)
                    )
                ),
                "agy": ProviderQuota(
                    provider: "agy", status: "error",
                    lastSuccessAt: now.addingTimeInterval(-3600),
                    windows: QuotaWindows(
                        fiveHour: UsageWindow(remainingPercent: 15.0, resetsAt: nil),
                        sevenDay: nil
                    )
                )
            ]
        )
        let state = QuotaDisplayState.map(response: response, fetchedAt: now, now: now)
        return QuotaEntry(date: now, displayState: state)
    }()
}
