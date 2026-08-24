import Testing
import Foundation
@testable import AIQuota

struct DateDecodingTests {
    @Test func testISO8601Decoding() throws {
        let jsonWithFractional = """
        {
            "schemaVersion": 1,
            "generatedAt": "2026-07-16T09:30:00.123Z",
            "providers": {
                "codex": {
                    "provider": "codex",
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
            }
        }
        """.data(using: .utf8)!
        
        let jsonWithoutFractional = """
        {
            "schemaVersion": 1,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "codex": {
                    "provider": "codex",
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
            }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601
        
        let response1 = try decoder.decode(QuotaResponse.self, from: jsonWithFractional)
        #expect(response1.schemaVersion == 1)
        #expect(response1.providers["codex"]?.lastSuccessAt != nil)
        
        let response2 = try decoder.decode(QuotaResponse.self, from: jsonWithoutFractional)
        #expect(response2.schemaVersion == 1)
    }
    
    @Test func testResetCreditsDecoding() throws {
        let json = """
        {
            "schemaVersion": 1,
            "generatedAt": "2026-07-16T09:30:00Z",
            "providers": {
                "codex": {
                    "provider": "codex",
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
            }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601
        let response = try decoder.decode(QuotaResponse.self, from: json)
        let credits = response.providers["codex"]?.resetCredits
        
        #expect(credits?.availableCount == 2)
        #expect(credits?.credits.count == 2)
        #expect(credits?.credits.last?.expiresAt == nil)
    }
}
