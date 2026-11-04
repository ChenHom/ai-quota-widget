import Testing
import Foundation
@testable import AIQuota

struct DateDecodingTests {
    @Test func testISO8601Decoding() throws {
        let jsonWithFractional = """
        {
            "schemaVersion": 3,
            "generatedAt": "2026-07-16T09:30:00.123Z",
            "providers": {
                "codex": [
                    {
                        "provider": "codex",
                        "account": "main",
                        "status": "ok",
                        "lastSuccessAt": "2026-07-16T09:29:30.456Z",
                        "windows": {
                            "five_hour": { "all": {
                                "remainingPercent": 82.4,
                                "resetsAt": "2026-07-16T12:00:00.000Z"
                            } },
                            "seven_day": null
                        }
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let jsonWithoutFractional = """
        {
            "schemaVersion": 3,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "codex": [
                    {
                        "provider": "codex",
                        "account": "main",
                        "status": "ok",
                        "lastSuccessAt": "2026-07-16T09:29:30Z",
                        "windows": {
                            "five_hour": { "all": {
                                "remainingPercent": 82.4,
                                "resetsAt": "2026-07-16T12:00:00Z"
                            } },
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
        #expect(response1.schemaVersion == 3)
        #expect(response1.primaryAccount(of: "codex")?.lastSuccessAt != nil)

        let response2 = try decoder.decode(QuotaResponse.self, from: jsonWithoutFractional)
        #expect(response2.schemaVersion == 3)
    }

    @Test func testResetCreditsDecoding() throws {
        let json = """
        {
            "schemaVersion": 3,
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
            "schemaVersion": 3,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "claude": [
                    {
                        "provider": "claude",
                        "account": "main",
                        "status": "ok",
                        "lastSuccessAt": "2026-07-16T09:29:45Z",
                        "windows": {
                            "five_hour": { "all": { "remainingPercent": 61.0, "resetsAt": null } },
                            "seven_day": null
                        }
                    },
                    {
                        "provider": "claude",
                        "account": "work",
                        "status": "ok",
                        "lastSuccessAt": "2026-07-16T09:29:45Z",
                        "windows": {
                            "five_hour": { "all": { "remainingPercent": 34.0, "resetsAt": null } },
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
        #expect(accounts[1].fiveHour()?.remainingPercent == 34.0)

        // 缺席的 provider 回傳空陣列而不是解碼失敗
        #expect(response.accounts(of: "agy").isEmpty)
        #expect(response.primaryAccount(of: "agy") == nil)
    }

    /// schema 文件要求以 `account` 比對而非索引：伺服器重排後仍要挑到 main。
    @Test func testPrimaryAccountMatchesByNameNotIndex() throws {
        let json = """
        {
            "schemaVersion": 3,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "claude": [
                    {
                        "provider": "claude",
                        "account": "work",
                        "status": "ok",
                        "lastSuccessAt": "2026-07-16T09:29:45Z",
                        "windows": {
                            "five_hour": { "all": { "remainingPercent": 34.0, "resetsAt": null } },
                            "seven_day": null
                        }
                    },
                    {
                        "provider": "claude",
                        "account": "main",
                        "status": "ok",
                        "lastSuccessAt": "2026-07-16T09:29:45Z",
                        "windows": {
                            "five_hour": { "all": { "remainingPercent": 61.0, "resetsAt": null } },
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
        #expect(response.primaryAccount(of: "claude")?.fiveHour()?.remainingPercent == 61.0)
    }

    /// 沒有 main 這個帳號時退回第一個元素，而不是整份快照不可用。
    @Test func testPrimaryAccountFallsBackToFirst() throws {
        let json = """
        {
            "schemaVersion": 3,
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
            "schemaVersion": 3,
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
            "schemaVersion": 3,
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
                            "five_hour": { "all": {
                                "usedPercent": 17.6,
                                "remainingPercent": 82.4,
                                "resetsAt": null
                            } },
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

        #expect(response.primaryAccount(of: "codex")?.fiveHour()?.remainingPercent == 82.4)
        #expect(response.primaryAccount(of: "codex")?.resetCredits?.availableCount == 1)
    }

    // MARK: - schema v3

    /// v3 每個期間底下分群組：null 群組不能讓整份解碼失敗，AGY 的主群組是 gemini，
    /// 而且經過快取的 encode／decode 之後群組要原樣保留（Widget 讀的是快取）。
    @Test func testV3GroupsDecoding() throws {
        let json = """
        {
            "schemaVersion": 3,
            "generatedAt": "2026-11-04T03:49:09.340Z",
            "providers": {
                "agy": [
                    {
                        "provider": "agy",
                        "account": "main",
                        "status": "ok",
                        "lastSuccessAt": "2026-11-04T03:49:09.340Z",
                        "windows": {
                            "five_hour": {
                                "gemini": { "usedPercent": 15.7, "remainingPercent": 84.3, "resetsAt": "2026-11-04T04:56:02.000Z" },
                                "claude_gpt": null,
                                "gemini_4_argon": null
                            },
                            "seven_day": {
                                "gemini": null,
                                "claude_gpt": { "usedPercent": 100, "remainingPercent": 0, "resetsAt": null,
                                                "displayName": "Claude and GPT models" },
                                "gemini_4_argon": null
                            }
                        },
                        "resetCredits": null
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601
        let decoded = try decoder.decode(QuotaResponse.self, from: json)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let roundTripped = try decoder.decode(QuotaResponse.self, from: encoder.encode(decoded))

        for response in [decoded, roundTripped] {
            let agy = try #require(response.primaryAccount(of: "agy"))
            #expect(agy.primaryGroup == "gemini")
            #expect(agy.groups == ["gemini", "claude_gpt", "gemini_4_argon"])
            #expect(agy.fiveHour()?.remainingPercent == 84.3)
            #expect(agy.sevenDay() == nil)                                // 群組是 null
            #expect(agy.fiveHour("missing") == nil)                       // 群組不存在
            #expect(agy.sevenDay("claude_gpt")?.remainingPercent == 0)    // 0% 是有效值，不是缺值
            #expect(agy.sevenDay("claude_gpt")?.displayName == "Claude and GPT models")
        }
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
