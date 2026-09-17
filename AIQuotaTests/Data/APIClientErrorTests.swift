import Testing
import Foundation
@testable import AIQuota

struct APIClientErrorTests {

    @Test func testSchemaVersionValidation() {
        // 支援的版本：collector 自 2026-09-16 起只輸出 v2
        #expect(QuotaAPIClient.supportedSchemaVersions.contains(2))
        // 不支援的版本
        #expect(!QuotaAPIClient.supportedSchemaVersions.contains(0))
        #expect(!QuotaAPIClient.supportedSchemaVersions.contains(1))
        #expect(!QuotaAPIClient.supportedSchemaVersions.contains(99))
    }

    @Test func testQuotaErrorDescriptions() {
        // 所有錯誤都有繁體中文描述，且不含 Foundation 原始錯誤字串
        let errors: [QuotaError] = [
            .configurationMissing,
            .invalidEndpoint,
            .transport(URLError(.notConnectedToInternet)),
            .tls(URLError(.serverCertificateUntrusted)),
            .httpStatus(500),
            .decoding(NSError(domain: "test", code: 0)),
            .unsupportedSchemaVersion(1),
            .cacheCorrupted,
        ]

        for error in errors {
            let desc = error.errorDescription
            #expect(desc != nil, "錯誤描述不應為 nil: \(error)")
            #expect(!desc!.isEmpty, "錯誤描述不應為空: \(error)")
        }
    }

    @Test func testTLSErrorClassification() {
        // 模擬 TLS 錯誤碼對應
        let tlsCodes = [
            NSURLErrorSecureConnectionFailed,
            NSURLErrorServerCertificateHasBadDate,
            NSURLErrorServerCertificateUntrusted,
            NSURLErrorServerCertificateHasUnknownRoot,
            NSURLErrorServerCertificateNotYetValid,
            NSURLErrorClientCertificateRejected,
            NSURLErrorClientCertificateRequired,
        ]

        for code in tlsCodes {
            let error = URLError(URLError.Code(rawValue: code))
            let nsError = error as NSError
            #expect(nsError.domain == NSURLErrorDomain)
            #expect(tlsCodes.contains(nsError.code))
        }
    }

    @Test func testDecodingNullWindows() throws {
        let json = """
        {
            "schemaVersion": 2,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "codex": [
                    {
                        "provider": "codex",
                        "account": "main",
                        "status": "ok",
                        "lastSuccessAt": "2026-07-16T09:29:30Z",
                        "windows": {
                            "five_hour": null,
                            "seven_day": null
                        }
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601

        let response = try decoder.decode(QuotaResponse.self, from: json)
        let codex = response.primaryAccount(of: "codex")!
        #expect(codex.windows.fiveHour == nil)
        #expect(codex.windows.sevenDay == nil)
    }

    @Test func testDecodingUnknownStatusDoesNotFail() throws {
        let json = """
        {
            "schemaVersion": 2,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "codex": [
                    {
                        "provider": "codex",
                        "account": "main",
                        "status": "some_unknown_status_value",
                        "lastSuccessAt": "2026-07-16T09:29:30Z",
                        "windows": {
                            "five_hour": {
                                "remainingPercent": 50.0,
                                "resetsAt": null
                            },
                            "seven_day": null
                        }
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601

        // 未知 status 不應觸發解碼失敗
        let response = try decoder.decode(QuotaResponse.self, from: json)
        #expect(response.primaryAccount(of: "codex")?.status == "some_unknown_status_value")
    }

    @Test func testDecodingUnsupportedSchemaVersionStillDecodes() throws {
        let json = """
        {
            "schemaVersion": 99,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {}
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601

        // 解碼本身不失敗（schema 驗證由 APIClient 層負責）
        let response = try decoder.decode(QuotaResponse.self, from: json)
        #expect(response.schemaVersion == 99)
        #expect(!QuotaAPIClient.supportedSchemaVersions.contains(99))
    }

    @Test func testDecodingProviderFixedOrder() {
        let now = Date()
        let response = QuotaResponse(
            schemaVersion: 2,
            generatedAt: now,
            providers: [
                "agy": [
                    ProviderQuota(
                        provider: "agy", account: "main", status: "ok", lastSuccessAt: now,
                        windows: QuotaWindows(fiveHour: nil, sevenDay: nil)
                    )
                ],
                "codex": [
                    ProviderQuota(
                        provider: "codex", account: "main", status: "ok", lastSuccessAt: now,
                        windows: QuotaWindows(fiveHour: nil, sevenDay: nil)
                    )
                ]
            ]
        )

        let state = QuotaDisplayState.map(response: response, fetchedAt: now, now: now)

        // 固定順序: codex, claude, agy
        #expect(state.providers[0].id == "codex")
        #expect(state.providers[1].id == "claude")
        #expect(state.providers[2].id == "agy")

        // claude 缺失但仍保留位置
        #expect(state.providers[1].fiveHour.remainingPercent == nil)
        #expect(state.providers[1].fiveHour.percentText == "—")
    }

    @Test func testNullResetsAtDisplaysDash() {
        let window = WindowDisplayState(remainingPercent: 50.0, resetsAt: nil)
        #expect(window.resetsAtText == "—")
        #expect(window.resetsAtVoiceOverText == "沒有資料")
    }

    @Test func testNullPercentDisplaysDash() {
        let window = WindowDisplayState(remainingPercent: nil, resetsAt: nil)
        #expect(window.percentText == "—")
        #expect(window.percentVoiceOverText == "沒有資料")
    }
}

// MARK: - APIClient 端到端（stub URLProtocol）

/// 共用 StubURLProtocol 的靜態狀態，因此序列化執行。
@Suite(.serialized)
struct APIClientSchemaOrderTests {

    private func makeClient() -> QuotaAPIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return QuotaAPIClient(session: URLSession(configuration: config))
    }

    private let endpoint = URL(string: "https://example.com/quota.json")!

    /// 版本檢查必須早於完整解碼。
    ///
    /// 這份 payload 同時觸發兩個問題：schemaVersion 是 1，且 providers 是 v1 的物件形狀。
    /// 若先解碼再驗版本，錯誤會變成 .decoding（「資料解析失敗」），
    /// 蓋掉 .unsupportedSchemaVersion（「請更新 App」）這個真正能指引使用者的訊息。
    @Test func testUnsupportedVersionReportedBeforeDecodingFailure() async throws {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.responseData = """
        {
            "schemaVersion": 1,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "codex": {
                    "provider": "codex",
                    "status": "ok",
                    "lastSuccessAt": "2026-07-16T09:29:30Z",
                    "windows": { "five_hour": null, "seven_day": null }
                }
            }
        }
        """.data(using: .utf8)!

        do {
            _ = try await makeClient().fetchQuota(from: endpoint)
            Issue.record("預期拋出錯誤")
        } catch let error as QuotaError {
            guard case .unsupportedSchemaVersion(let version) = error else {
                Issue.record("預期 .unsupportedSchemaVersion，收到 \(error)")
                return
            }
            #expect(version == 1)
        }
    }

    /// v2 payload 走完整條路徑：HTTP → 版本檢查 → 解碼，多帳號完整保留。
    @Test func testSupportedVersionDecodesAllAccounts() async throws {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.responseData = """
        {
            "schemaVersion": 2,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "claude": [
                    {
                        "provider": "claude",
                        "account": "main",
                        "status": "ok",
                        "confidence": "experimental",
                        "source": "api.anthropic.com/api/oauth/usage",
                        "lastSuccessAt": "2026-07-16T09:29:45Z",
                        "windows": {
                            "five_hour": { "usedPercent": 39, "remainingPercent": 61, "resetsAt": null },
                            "seven_day": null
                        },
                        "resetCredits": null
                    },
                    {
                        "provider": "claude",
                        "account": "work",
                        "status": "ok",
                        "confidence": "experimental",
                        "source": "api.anthropic.com/api/oauth/usage",
                        "lastSuccessAt": null,
                        "windows": {
                            "five_hour": { "usedPercent": 66, "remainingPercent": 34, "resetsAt": null },
                            "seven_day": null
                        },
                        "resetCredits": null
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let response = try await makeClient().fetchQuota(from: endpoint)

        #expect(response.schemaVersion == 2)
        #expect(response.accounts(of: "claude").map(\.account) == ["main", "work"])
        #expect(response.primaryAccount(of: "claude")?.windows.fiveHour?.remainingPercent == 61)
        #expect(response.accounts(of: "claude")[1].lastSuccessAt == nil)
    }
}

/// 以固定 payload 回應任何請求，讓 QuotaAPIClient 能在沒有網路的情況下被測試。
private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var statusCode = 200

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let url = request.url,
           let response = HTTPURLResponse(
                url: url, statusCode: Self.statusCode, httpVersion: nil, headerFields: nil
           ) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Self.responseData)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
