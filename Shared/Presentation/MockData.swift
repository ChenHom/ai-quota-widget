import Foundation

public enum MockData {
    public static var normalQuota: QuotaResponse {
        let now = Date()
        return QuotaResponse(
            schemaVersion: 2,
            generatedAt: now.addingTimeInterval(-300), // 5 分鐘前
            providers: [
                "codex": [
                    ProviderQuota(
                        provider: "codex",
                        account: "main",
                        status: "ok",
                        lastSuccessAt: now.addingTimeInterval(-320),
                        windows: QuotaWindows(
                            fiveHour: UsageWindow(remainingPercent: 82.4, resetsAt: now.addingTimeInterval(7200)),
                            sevenDay: UsageWindow(remainingPercent: 54.0, resetsAt: nil)
                        )
                    )
                ],
                "claude": [
                    ProviderQuota(
                        provider: "claude",
                        account: "main",
                        status: "ok",
                        lastSuccessAt: now.addingTimeInterval(-305),
                        windows: QuotaWindows(
                            fiveHour: UsageWindow(remainingPercent: 63.0, resetsAt: now.addingTimeInterval(3600)),
                            sevenDay: UsageWindow(remainingPercent: 78.5, resetsAt: now.addingTimeInterval(86400 * 3))
                        ),
                        resetCredits: ResetCredits(
                            availableCount: 2,
                            credits: [
                                ResetCredit(status: "available", grantedAt: now.addingTimeInterval(-86400 * 10), expiresAt: now.addingTimeInterval(86400 * 20)),
                                ResetCredit(status: "available", grantedAt: now.addingTimeInterval(-86400 * 3), expiresAt: nil)
                            ]
                        )
                    ),
                    // 第二個帳號：目前 UI 只顯示 main，留在這裡是為了讓預覽與測試走到多帳號路徑
                    ProviderQuota(
                        provider: "claude",
                        account: "work",
                        status: "ok",
                        lastSuccessAt: now.addingTimeInterval(-305),
                        windows: QuotaWindows(
                            fiveHour: UsageWindow(remainingPercent: 34.0, resetsAt: now.addingTimeInterval(5400)),
                            sevenDay: UsageWindow(remainingPercent: 88.0, resetsAt: now.addingTimeInterval(86400))
                        )
                    )
                ],
                "agy": [
                    ProviderQuota(
                        provider: "agy",
                        account: "main",
                        status: "ok",
                        lastSuccessAt: now.addingTimeInterval(-340),
                        windows: QuotaWindows(
                            fiveHour: UsageWindow(remainingPercent: 41.0, resetsAt: now.addingTimeInterval(1800)),
                            sevenDay: nil
                        )
                    )
                ]
            ]
        )
    }

    public static var delayedQuota: QuotaResponse {
        let now = Date()
        return QuotaResponse(
            schemaVersion: 2,
            generatedAt: now.addingTimeInterval(-1800), // 30 分鐘前
            providers: [
                "codex": [
                    ProviderQuota(
                        provider: "codex",
                        account: "main",
                        status: "ok",
                        lastSuccessAt: now.addingTimeInterval(-1820),
                        windows: QuotaWindows(
                            fiveHour: UsageWindow(remainingPercent: 5.0, resetsAt: now.addingTimeInterval(300)),
                            sevenDay: UsageWindow(remainingPercent: 20.0, resetsAt: nil)
                        )
                    )
                ],
                "claude": [
                    ProviderQuota(
                        provider: "claude",
                        account: "main",
                        status: "rate_limited", // 異常
                        lastSuccessAt: now.addingTimeInterval(-3600),
                        windows: QuotaWindows(
                            fiveHour: UsageWindow(remainingPercent: 0.0, resetsAt: now.addingTimeInterval(7200)),
                            sevenDay: UsageWindow(remainingPercent: 60.0, resetsAt: now.addingTimeInterval(86400))
                        )
                    )
                ],
                "agy": [
                    ProviderQuota(
                        provider: "agy",
                        account: "main",
                        status: "ok",
                        lastSuccessAt: now.addingTimeInterval(-1900),
                        windows: QuotaWindows(
                            fiveHour: UsageWindow(remainingPercent: 12.0, resetsAt: now.addingTimeInterval(900)),
                            sevenDay: nil
                        )
                    )
                ]
            ]
        )
    }

    public static var staleQuota: QuotaResponse {
        let now = Date()
        return QuotaResponse(
            schemaVersion: 2,
            generatedAt: now.addingTimeInterval(-7200), // 2 小時前
            providers: [
                "codex": [
                    ProviderQuota(
                        provider: "codex",
                        account: "main",
                        status: "ok",
                        lastSuccessAt: now.addingTimeInterval(-7220),
                        windows: QuotaWindows(
                            fiveHour: UsageWindow(remainingPercent: 82.4, resetsAt: now.addingTimeInterval(7200)),
                            sevenDay: UsageWindow(remainingPercent: 54.0, resetsAt: nil)
                        )
                    )
                ],
                "claude": [
                    ProviderQuota(
                        provider: "claude",
                        account: "main",
                        status: "ok",
                        lastSuccessAt: now.addingTimeInterval(-7205),
                        windows: QuotaWindows(
                            fiveHour: UsageWindow(remainingPercent: 63.0, resetsAt: now.addingTimeInterval(3600)),
                            sevenDay: UsageWindow(remainingPercent: 78.5, resetsAt: now.addingTimeInterval(86400 * 3))
                        )
                    )
                ],
                "agy": [
                    ProviderQuota(
                        provider: "agy",
                        account: "main",
                        status: "ok",
                        lastSuccessAt: now.addingTimeInterval(-7240),
                        windows: QuotaWindows(
                            fiveHour: UsageWindow(remainingPercent: 41.0, resetsAt: now.addingTimeInterval(1800)),
                            sevenDay: nil
                        )
                    )
                ]
            ]
        )
    }
}
