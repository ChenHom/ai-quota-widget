import Foundation

// MARK: - QuotaFetching Protocol

/// 定義從遠端 HTTPS endpoint 取得 quota 資料的介面。
/// 透過 protocol 讓測試能注入 mock 實作。
public protocol QuotaFetching: Sendable {
    func fetchQuota(from endpoint: URL) async throws -> QuotaResponse
}

// MARK: - QuotaAPIClient

/// 實際的 HTTP client，負責下載並解碼 quota.json。
/// 所有網路與解碼錯誤都轉換為型別化的 QuotaError。
public struct QuotaAPIClient: QuotaFetching, Sendable {
    
    /// 目前支援的 schema versions。collector 自 2026-09-16 起只輸出 v2，v1 不再提供。
    public static let supportedSchemaVersions: Set<Int> = [2]
    
    private let session: URLSession
    
    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: config)
        }
    }
    
    public func fetchQuota(from endpoint: URL) async throws -> QuotaResponse {
        var request = URLRequest(url: endpoint)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        // 發送網路請求，分類傳輸與 TLS 錯誤
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw classifyTransportError(error)
        }
        
        // 驗證 HTTP 狀態碼
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.transport(URLError(.badServerResponse))
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw QuotaError.httpStatus(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601

        // 先驗證 schema version，再做完整解碼。
        // 順序不能反過來：跨版本連 `providers` 的形狀都會變（v1 是物件、v2 是陣列），
        // 先完整解碼會讓「版本不符」表現成 .decoding（「資料解析失敗」），
        // 蓋掉「請更新 App」這個真正能指引使用者的訊息。
        let probe: SchemaProbe
        do {
            probe = try decoder.decode(SchemaProbe.self, from: data)
        } catch {
            throw QuotaError.decoding(error)
        }

        guard Self.supportedSchemaVersions.contains(probe.schemaVersion) else {
            throw QuotaError.unsupportedSchemaVersion(probe.schemaVersion)
        }

        // 解碼 JSON
        do {
            return try decoder.decode(QuotaResponse.self, from: data)
        } catch {
            throw QuotaError.decoding(error)
        }
    }

    /// 只取 `schemaVersion` 的輕量型別，供版本檢查先行。
    private struct SchemaProbe: Decodable {
        let schemaVersion: Int
    }
    
    // MARK: - 錯誤分類
    
    /// 將 URLSession 錯誤轉換為 QuotaError.transport 或 QuotaError.tls。
    private func classifyTransportError(_ error: Error) -> QuotaError {
        let nsError = error as NSError
        
        // TLS 相關錯誤碼
        let tlsErrorCodes: Set<Int> = [
            NSURLErrorSecureConnectionFailed,      // -1200
            NSURLErrorServerCertificateHasBadDate,  // -1201
            NSURLErrorServerCertificateUntrusted,   // -1202
            NSURLErrorServerCertificateHasUnknownRoot, // -1203
            NSURLErrorServerCertificateNotYetValid, // -1204
            NSURLErrorClientCertificateRejected,    // -1205
            NSURLErrorClientCertificateRequired,    // -1206
        ]
        
        if nsError.domain == NSURLErrorDomain && tlsErrorCodes.contains(nsError.code) {
            return .tls(error)
        }
        
        return .transport(error)
    }
}
