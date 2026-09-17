import Testing
import Foundation
@testable import AIQuota

struct QuotaCacheTests {
    
    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("test_cache_\(UUID().uuidString)")
    }
    
    private func makeCache(containerURL: URL) -> QuotaCache {
        try? FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        return QuotaCache(containerURL: containerURL)
    }
    
    private func makeSampleCached() -> CachedQuota {
        let response = QuotaResponse(
            schemaVersion: 2,
            generatedAt: Date(),
            providers: [
                "codex": [
                    ProviderQuota(
                        provider: "codex",
                        account: "main",
                        status: "ok",
                        lastSuccessAt: Date(),
                        windows: QuotaWindows(
                            fiveHour: UsageWindow(remainingPercent: 82.4, resetsAt: nil),
                            sevenDay: nil
                        )
                    )
                ]
            ]
        )
        return CachedQuota(quota: response, fetchedAt: Date())
    }
    
    @Test func testSaveAndLoad() throws {
        let dir = makeTempURL()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = makeCache(containerURL: dir)
        
        let sample = makeSampleCached()
        try cache.save(sample)
        
        let loaded = cache.load()
        #expect(loaded != nil)
        #expect(loaded?.quota.schemaVersion == 2)
        #expect(loaded?.quota.primaryAccount(of: "codex")?.status == "ok")
    }

    /// 快取是自家編碼再自家解碼，多帳號必須完整往返（含順序與 account 標籤）。
    @Test func testMultiAccountRoundTrip() throws {
        let dir = makeTempURL()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = makeCache(containerURL: dir)

        let response = QuotaResponse(
            schemaVersion: 2,
            generatedAt: Date(),
            providers: [
                "claude": [
                    ProviderQuota(
                        provider: "claude", account: "main", status: "ok",
                        lastSuccessAt: Date(),
                        windows: QuotaWindows(
                            fiveHour: UsageWindow(remainingPercent: 61, resetsAt: nil),
                            sevenDay: nil
                        )
                    ),
                    ProviderQuota(
                        provider: "claude", account: "work", status: "ok",
                        lastSuccessAt: nil,
                        windows: QuotaWindows(
                            fiveHour: UsageWindow(remainingPercent: 34, resetsAt: nil),
                            sevenDay: nil
                        )
                    )
                ]
            ]
        )
        try cache.save(CachedQuota(quota: response, fetchedAt: Date()))

        let loaded = cache.load()
        let accounts = loaded?.quota.accounts(of: "claude") ?? []
        #expect(accounts.map(\.account) == ["main", "work"])
        #expect(accounts.last?.lastSuccessAt == nil)
        #expect(accounts.last?.windows.fiveHour?.remainingPercent == 34)
    }
    
    @Test func testLoadReturnsNilWhenEmpty() {
        let dir = makeTempURL()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = makeCache(containerURL: dir)
        
        let loaded = cache.load()
        #expect(loaded == nil)
    }
    
    @Test func testCorruptedCacheReturnsNil() throws {
        let dir = makeTempURL()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = makeCache(containerURL: dir)
        
        // 寫入損壞資料
        let corruptedData = "this is not json".data(using: .utf8)!
        let filePath = dir.appendingPathComponent(AppGroupConstants.cacheFileName)
        try corruptedData.write(to: filePath)
        
        let loaded = cache.load()
        #expect(loaded == nil) // 不 crash，回傳 nil
    }
    
    @Test func testClearRemovesCache() throws {
        let dir = makeTempURL()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cache = makeCache(containerURL: dir)
        
        let sample = makeSampleCached()
        try cache.save(sample)
        #expect(cache.load() != nil)
        
        cache.clear()
        #expect(cache.load() == nil)
    }
}
