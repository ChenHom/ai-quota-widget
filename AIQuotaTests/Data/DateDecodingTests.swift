import Testing
import Foundation
@testable import AIQuota

struct DateDecodingTests {
    @Test func testISO8601Decoding() throws {
        let jsonWithFractional = """
        {
            "schemaVersion": 2,
            "generatedAt": "2026-07-16T09:30:00.123Z",
            "providers": {
                "codex": [
                    {
                        "provider": "codex",
                        "account": "main",
                        "status": "ok",
                        "lastSuccessAt": "2026-07-16T09:29:30.456Z",
                        "windows": {
                            "five_hour": {
                                "remainingPercent": 82.4,
                                "resetsAt": "2026-07-16T12:00:00.000Z"
                            },
                            "seven_day": null
                        }
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let jsonWithoutFractional = """
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
                            "five_hour": {
                                "remainingPercent": 82.4,
                                "resetsAt": "2026-07-16T12:00:00Z"
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

        let response1 = try decoder.decode(QuotaResponse.self, from: jsonWithFractional)
        #expect(response1.schemaVersion == 2)
        #expect(response1.primaryAccount(of: "codex")?.lastSuccessAt != nil)

        let response2 = try decoder.decode(QuotaResponse.self, from: jsonWithoutFractional)
        #expect(response2.schemaVersion == 2)
    }

    @Test func testResetCreditsDecoding() throws {
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
                        "windows": { "five_hour": null, "seven_day": null },
                        "resetCredits": {
                            "availableCount": 2,
                            "applicableAvailableCount": 1,
                            "credits": [
                                {
                                    "status": "available",
                                    "grantedAt": "2026-07-01T00:00:00Z",
                                    "expiresAt": "2026-08-01T00:00:00Z"
                                },
                                {
                                    "status": "available",
                                    "grantedAt": "2026-07-10T00:00:00Z",
                                    "expiresAt": null
                                }
                            ]
                        }
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601
        let response = try decoder.decode(QuotaResponse.self, from: json)
        let credits = response.primaryAccount(of: "codex")?.resetCredits

        #expect(credits?.availableCount == 2)
        #expect(credits?.credits.count == 2)
        #expect(credits?.credits.last?.expiresAt == nil)
    }

    // MARK: - schema v2

    /// 同一個 provider 的多個帳號都要完整保留，順序照伺服器給的。
    @Test func testMultipleAccountsDecoding() throws {
        let json = """
        {
            "schemaVersion": 2,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "claude": [
                    {
                        "provider": "claude",
                        "account": "main",
                        "status": "ok",
                        "lastSuccessAt": "2026-07-16T09:29:45Z",
                        "windows": {
                            "five_hour": { "remainingPercent": 61.0, "resetsAt": null },
                            "seven_day": null
                        }
                    },
                    {
                        "provider": "claude",
                        "account": "work",
                        "status": "ok",
                        "lastSuccessAt": "2026-07-16T09:29:45Z",
                        "windows": {
                            "five_hour": { "remainingPercent": 34.0, "resetsAt": null },
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

        let accounts = response.accounts(of: "claude")
        #expect(accounts.count == 2)
        #expect(accounts.map(\.account) == ["main", "work"])
        #expect(accounts[1].windows.fiveHour?.remainingPercent == 34.0)

        // 缺席的 provider 回傳空陣列而不是解碼失敗
        #expect(response.accounts(of: "agy").isEmpty)
        #expect(response.primaryAccount(of: "agy") == nil)
    }

    /// schema 文件要求以 `account` 比對而非索引：伺服器重排後仍要挑到 main。
    @Test func testPrimaryAccountMatchesByNameNotIndex() throws {
        let json = """
        {
            "schemaVersion": 2,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "claude": [
                    {
                        "provider": "claude",
                        "account": "work",
                        "status": "ok",
                        "lastSuccessAt": "2026-07-16T09:29:45Z",
                        "windows": {
                            "five_hour": { "remainingPercent": 34.0, "resetsAt": null },
                            "seven_day": null
                        }
                    },
                    {
                        "provider": "claude",
                        "account": "main",
                        "status": "ok",
                        "lastSuccessAt": "2026-07-16T09:29:45Z",
                        "windows": {
                            "five_hour": { "remainingPercent": 61.0, "resetsAt": null },
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

        #expect(response.primaryAccount(of: "claude")?.account == "main")
        #expect(response.primaryAccount(of: "claude")?.windows.fiveHour?.remainingPercent == 61.0)
    }

    /// 沒有 main 這個帳號時退回第一個元素，而不是整份快照不可用。
    @Test func testPrimaryAccountFallsBackToFirst() throws {
        let json = """
        {
            "schemaVersion": 2,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "claude": [
                    {
                        "provider": "claude",
                        "account": "personal",
                        "status": "ok",
                        "lastSuccessAt": "2026-07-16T09:29:45Z",
                        "windows": { "five_hour": null, "seven_day": null }
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601
        let response = try decoder.decode(QuotaResponse.self, from: json)

        #expect(response.primaryAccount(of: "claude")?.account == "personal")
    }

    /// v2 起 `lastSuccessAt` 可能是 null，不可解碼失敗。
    @Test func testNullLastSuccessAtDecodes() throws {
        let json = """
        {
            "schemaVersion": 2,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "agy": [
                    {
                        "provider": "agy",
                        "account": "main",
                        "status": "unavailable",
                        "lastSuccessAt": null,
                        "windows": { "five_hour": null, "seven_day": null }
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601
        let response = try decoder.decode(QuotaResponse.self, from: json)

        #expect(response.primaryAccount(of: "agy")?.lastSuccessAt == nil)
        #expect(response.primaryAccount(of: "agy")?.status == "unavailable")
    }

    /// v2 的 `confidence`／`source`／`usedPercent` 目前不解碼，出現時必須被忽略而非失敗。
    @Test func testUnknownV2FieldsAreIgnored() throws {
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
                        "confidence": "experimental",
                        "source": "chatgpt.com/backend-api/wham/usage",
                        "lastSuccessAt": "2026-07-16T09:29:30Z",
                        "windows": {
                            "five_hour": {
                                "usedPercent": 17.6,
                                "remainingPercent": 82.4,
                                "resetsAt": null
                            },
                            "seven_day": null
                        },
                        "resetCredits": {
                            "availableCount": 1,
                            "applicableAvailableCount": 1,
                            "credits": [
                                {
                                    "status": "available",
                                    "grantedAt": "2026-07-01T00:00:00Z",
                                    "expiresAt": null
                                }
                            ]
                        }
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601
        let response = try decoder.decode(QuotaResponse.self, from: json)

        #expect(response.primaryAccount(of: "codex")?.windows.fiveHour?.remainingPercent == 82.4)
        #expect(response.primaryAccount(of: "codex")?.resetCredits?.availableCount == 1)
    }

    /// v1 的 providers 是單一物件，v2 的解碼型別必須拒絕它（而非誤讀）。
    @Test func testLegacyV1ShapeFailsToDecode() {
        let json = """
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

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601

        #expect(throws: (any Error).self) {
            try decoder.decode(QuotaResponse.self, from: json)
        }
    }
}
