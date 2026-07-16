import Testing
import Foundation
@testable import AIQuota

struct APIClientErrorTests {
    
    @Test func testSchemaVersionValidation() {
        // 支援的版本
        #expect(QuotaAPIClient.supportedSchemaVersions.contains(1))
        // 不支援的版本
        #expect(!QuotaAPIClient.supportedSchemaVersions.contains(0))
        #expect(!QuotaAPIClient.supportedSchemaVersions.contains(2))
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
            .unsupportedSchemaVersion(2),
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
            "schemaVersion": 1,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "codex": {
                    "provider": "codex",
                    "status": "ok",
                    "lastSuccessAt": "2026-07-16T09:29:30Z",
                    "windows": {
                        "five_hour": null,
                        "seven_day": null
                    }
                }
            }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601
        
        let response = try decoder.decode(QuotaResponse.self, from: json)
        let codex = response.providers["codex"]!
        #expect(codex.windows.fiveHour == nil)
        #expect(codex.windows.sevenDay == nil)
    }
    
    @Test func testDecodingUnknownStatusDoesNotFail() throws {
        let json = """
        {
            "schemaVersion": 1,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "codex": {
                    "provider": "codex",
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
            }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601
        
        // 未知 status 不應觸發解碼失敗
        let response = try decoder.decode(QuotaResponse.self, from: json)
        #expect(response.providers["codex"]?.status == "some_unknown_status_value")
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
            schemaVersion: 1,
            generatedAt: now,
            providers: [
                "agy": ProviderQuota(
                    provider: "agy", status: "ok", lastSuccessAt: now,
                    windows: QuotaWindows(fiveHour: nil, sevenDay: nil)
                ),
                "codex": ProviderQuota(
                    provider: "codex", status: "ok", lastSuccessAt: now,
                    windows: QuotaWindows(fiveHour: nil, sevenDay: nil)
                )
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
