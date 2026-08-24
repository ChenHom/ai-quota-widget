import Testing
import Foundation
@testable import AIQuota

struct QuotaDisplayMappingTests {
    
    // 固定的當前時間: 2026-07-16T10:00:00Z
    private var fixedNow: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter.date(from: "2026-07-16T10:00:00Z")!
    }
    
    @Test func testNormalMapping() {
        let response = QuotaResponse(
            schemaVersion: 1,
            generatedAt: fixedNow.addingTimeInterval(-300), // 5 分鐘前 (fresh)
            providers: [
                "codex": ProviderQuota(
                    provider: "codex",
                    status: "ok",
                    lastSuccessAt: fixedNow.addingTimeInterval(-330),
                    windows: QuotaWindows(
                        fiveHour: UsageWindow(remainingPercent: 82.4, resetsAt: fixedNow.addingTimeInterval(7200)),
                        sevenDay: UsageWindow(remainingPercent: 54.0, resetsAt: nil)
                    )
                )
            ]
        )
        
        let state = QuotaDisplayState.map(response: response, fetchedAt: fixedNow, now: fixedNow)
        
        #expect(state.freshness == .fresh)
        #expect(state.providers.count == 3) // 固定 3 個 Provider
        
        // 檢查 Codex
        let codex = state.providers.first(where: { $0.id == "codex" })!
        #expect(codex.displayName == "Codex")
        #expect(codex.status == .ok)
        #expect(codex.fiveHour.percentText == "82%")
        #expect(codex.sevenDay.percentText == "54%")
        #expect(codex.sevenDay.resetsAtText == "—")
        
        // 檢查 Claude (缺失，應該是佔位符)
        let claude = state.providers.first(where: { $0.id == "claude" })!
        #expect(claude.displayName == "Claude")
        #expect(claude.status == .unknown("沒有資料"))
        #expect(claude.fiveHour.remainingPercent == nil)
        #expect(claude.fiveHour.percentText == "—")
    }
    
    @Test func testResetCreditsMapping() {
        let response = QuotaResponse(
            schemaVersion: 1,
            generatedAt: fixedNow,
            providers: [
                // 有券：徽章顯示張數，到期清單依 JSON 原順序
                "codex": ProviderQuota(
                    provider: "codex",
                    status: "ok",
                    lastSuccessAt: fixedNow,
                    windows: QuotaWindows(fiveHour: nil, sevenDay: nil),
                    resetCredits: ResetCredits(
                        availableCount: 2,
                        credits: [
                            ResetCredit(status: "available", grantedAt: fixedNow, expiresAt: fixedNow.addingTimeInterval(7200)),
                            ResetCredit(status: "available", grantedAt: fixedNow, expiresAt: nil)
                        ]
                    )
                ),
                // 0 張：完全不顯示徽章
                "claude": ProviderQuota(
                    provider: "claude",
                    status: "ok",
                    lastSuccessAt: fixedNow,
                    windows: QuotaWindows(fiveHour: nil, sevenDay: nil),
                    resetCredits: ResetCredits(availableCount: 0, credits: [])
                ),
                // 沒有 resetCredits 欄位的 Provider 不受影響
                "agy": ProviderQuota(
                    provider: "agy",
                    status: "ok",
                    lastSuccessAt: fixedNow,
                    windows: QuotaWindows(fiveHour: nil, sevenDay: nil)
                )
            ]
        )
        
        let state = QuotaDisplayState.map(response: response, fetchedAt: fixedNow, now: fixedNow)
        
        let codex = state.providers.first(where: { $0.id == "codex" })!
        #expect(codex.resetCredits?.badgeText == "+2")
        // 2026-07-16T12:00:00Z 固定以 Asia/Taipei（+8）顯示，不隨裝置時區改變
        #expect(codex.resetCredits?.expiryTexts == ["07/16 20:00", "—"])
        
        #expect(state.providers.first(where: { $0.id == "claude" })!.resetCredits == nil)
        #expect(state.providers.first(where: { $0.id == "agy" })!.resetCredits == nil)
    }
    
    @Test func testPercentClippingAndOptionalMapping() {
        let response = QuotaResponse(
            schemaVersion: 1,
            generatedAt: fixedNow.addingTimeInterval(-1000), // 16 分鐘前 (delayed)
            providers: [
                "codex": ProviderQuota(
                    provider: "codex",
                    status: "rate_limited",
                    lastSuccessAt: fixedNow.addingTimeInterval(-1200),
                    windows: QuotaWindows(
                        fiveHour: UsageWindow(remainingPercent: 120.0, resetsAt: nil), // 超過 100
                        sevenDay: UsageWindow(remainingPercent: -10.0, resetsAt: nil)  // 低於 0
                    )
                )
            ]
        )
        
        let state = QuotaDisplayState.map(response: response, fetchedAt: fixedNow, now: fixedNow)
        
        #expect(state.freshness == .delayed)
        
        let codex = state.providers.first(where: { $0.id == "codex" })!
        #expect(codex.status == .unknown("rate_limited"))
        #expect(codex.fiveHour.remainingPercent == 100.0) // 限制在 100
        #expect(codex.sevenDay.remainingPercent == 0.0)   // 限制在 0
    }
    
    @Test func testFreshnessPolicy() {
        // < 15 分鐘 -> fresh
        let freshDate = fixedNow.addingTimeInterval(-899)
        #expect(FreshnessPolicy.evaluate(generatedAt: freshDate, now: fixedNow) == .fresh)
        
        // >= 15 分鐘且 < 60 分鐘 -> delayed
        let delayedDate1 = fixedNow.addingTimeInterval(-900)
        let delayedDate2 = fixedNow.addingTimeInterval(-3599)
        #expect(FreshnessPolicy.evaluate(generatedAt: delayedDate1, now: fixedNow) == .delayed)
        #expect(FreshnessPolicy.evaluate(generatedAt: delayedDate2, now: fixedNow) == .delayed)
        
        // >= 60 分鐘 -> stale
        let staleDate = fixedNow.addingTimeInterval(-3600)
        #expect(FreshnessPolicy.evaluate(generatedAt: staleDate, now: fixedNow) == .stale)
        
        // 未來時間限制年齡為 0 -> fresh
        let futureDate = fixedNow.addingTimeInterval(3600)
        #expect(FreshnessPolicy.evaluate(generatedAt: futureDate, now: fixedNow) == .fresh)
    }
}
