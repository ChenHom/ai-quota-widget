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
            schemaVersion: 1,
            generatedAt: Date(),
            providers: [
                "codex": ProviderQuota(
                    provider: "codex",
                    status: "ok",
                    lastSuccessAt: Date(),
                    windows: QuotaWindows(
                        fiveHour: UsageWindow(remainingPercent: 82.4, resetsAt: nil),
                        sevenDay: nil
                    )
                )
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
        #expect(loaded?.quota.schemaVersion == 1)
        #expect(loaded?.quota.providers["codex"]?.status == "ok")
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
