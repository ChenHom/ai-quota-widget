import Testing
import Foundation
@testable import AIQuota

// MARK: - Mock Fetcher

private struct MockFetcher: QuotaFetching {
    let result: Result<QuotaResponse, Error>
    
    func fetchQuota(from endpoint: URL) async throws -> QuotaResponse {
        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}

struct QuotaRepositoryTests {
    
    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_repo_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.repo.\(UUID().uuidString)")!
    }
    
    private func makeResponse() -> QuotaResponse {
        QuotaResponse(
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
                            fiveHour: UsageWindow(remainingPercent: 75, resetsAt: nil),
                            sevenDay: nil
                        )
                    )
                ]
            ]
        )
    }
    
    @Test func testFreshResultOnSuccess() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let defaults = makeDefaults()
        
        let store = EndpointStore(defaults: defaults)
        store.saveEndpoint("https://example.com/quota.json")
        
        let fetcher = MockFetcher(result: .success(makeResponse()))
        let cache = QuotaCache(containerURL: dir)
        let repo = QuotaRepository(fetcher: fetcher, cache: cache, endpointStore: store)
        
        let result = await repo.latestQuota()
        
        switch result {
        case .fresh(let cached):
            #expect(cached.quota.schemaVersion == 2)
            #expect(cached.quota.primaryAccount(of: "codex")?.status == "ok")
            // 快取也應寫入
            #expect(cache.load() != nil)
        default:
            Issue.record("預期 .fresh 但收到 \(result)")
        }
    }
    
    @Test func testCachedResultOnNetworkFailure() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let defaults = makeDefaults()
        
        let store = EndpointStore(defaults: defaults)
        store.saveEndpoint("https://example.com/quota.json")
        
        // 先寫入快取
        let cache = QuotaCache(containerURL: dir)
        let response = makeResponse()
        try? cache.save(CachedQuota(quota: response, fetchedAt: Date()))
        
        // Fetcher 失敗
        let fetcher = MockFetcher(result: .failure(QuotaError.httpStatus(500)))
        let repo = QuotaRepository(fetcher: fetcher, cache: cache, endpointStore: store)
        
        let result = await repo.latestQuota()
        
        switch result {
        case .cached(let cached, let reason):
            #expect(cached.quota.schemaVersion == 2)
            if case .networkError(let error) = reason {
                if case .httpStatus(let code) = error {
                    #expect(code == 500)
                } else {
                    Issue.record("預期 httpStatus 錯誤")
                }
            } else {
                Issue.record("預期 .networkError")
            }
        default:
            Issue.record("預期 .cached 但收到 \(result)")
        }
    }
    
    @Test func testUnavailableWhenNoEndpointNoCache() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let defaults = makeDefaults()
        
        let store = EndpointStore(defaults: defaults)
        // 不設定 endpoint
        
        let fetcher = MockFetcher(result: .failure(QuotaError.configurationMissing))
        let cache = QuotaCache(containerURL: dir)
        let repo = QuotaRepository(fetcher: fetcher, cache: cache, endpointStore: store)
        
        let result = await repo.latestQuota()
        
        switch result {
        case .unavailable(let reason):
            if case .endpointNotConfigured = reason {
                // 正確
            } else {
                Issue.record("預期 .endpointNotConfigured")
            }
        default:
            Issue.record("預期 .unavailable 但收到 \(result)")
        }
    }
    
    @Test func testCachedWhenNoEndpointButCacheExists() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let defaults = makeDefaults()
        
        let store = EndpointStore(defaults: defaults)
        // 不設定 endpoint，但寫入快取
        
        let cache = QuotaCache(containerURL: dir)
        let response = makeResponse()
        try? cache.save(CachedQuota(quota: response, fetchedAt: Date()))
        
        let fetcher = MockFetcher(result: .failure(QuotaError.configurationMissing))
        let repo = QuotaRepository(fetcher: fetcher, cache: cache, endpointStore: store)
        
        let result = await repo.latestQuota()
        
        switch result {
        case .cached(_, let reason):
            if case .endpointNotConfigured = reason {
                // 正確：有快取但無 endpoint
            } else {
                Issue.record("預期 .endpointNotConfigured")
            }
        default:
            Issue.record("預期 .cached 但收到 \(result)")
        }
    }
    
    @Test func testUnavailableOnFailureWithoutCache() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let defaults = makeDefaults()
        
        let store = EndpointStore(defaults: defaults)
        store.saveEndpoint("https://example.com/quota.json")
        
        // 無快取，fetcher 失敗
        let fetcher = MockFetcher(result: .failure(QuotaError.httpStatus(503)))
        let cache = QuotaCache(containerURL: dir)
        let repo = QuotaRepository(fetcher: fetcher, cache: cache, endpointStore: store)
        
        let result = await repo.latestQuota()
        
        switch result {
        case .unavailable(let reason):
            if case .networkError(let error) = reason {
                if case .httpStatus(let code) = error {
                    #expect(code == 503)
                } else {
                    Issue.record("預期 httpStatus")
                }
            } else {
                Issue.record("預期 .networkError")
            }
        default:
            Issue.record("預期 .unavailable 但收到 \(result)")
        }
    }
    
    @Test func testSchemaVersionRejection() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let defaults = makeDefaults()
        
        let store = EndpointStore(defaults: defaults)
        store.saveEndpoint("https://example.com/quota.json")
        
        let fetcher = MockFetcher(
            result: .failure(QuotaError.unsupportedSchemaVersion(99))
        )
        let cache = QuotaCache(containerURL: dir)
        let repo = QuotaRepository(fetcher: fetcher, cache: cache, endpointStore: store)
        
        let result = await repo.latestQuota()
        
        switch result {
        case .unavailable(let reason):
            if case .networkError(let error) = reason,
               case .unsupportedSchemaVersion(let v) = error {
                #expect(v == 99)
            } else {
                Issue.record("預期 .unsupportedSchemaVersion(99)")
            }
        default:
            Issue.record("預期 .unavailable 但收到 \(result)")
        }
    }
}
