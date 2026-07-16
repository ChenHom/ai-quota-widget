import Foundation

public enum QuotaError: Error, LocalizedError, Sendable {
    case configurationMissing
    case invalidEndpoint
    case transport(Error)
    case tls(Error)
    case httpStatus(Int)
    case decoding(Error)
    case unsupportedSchemaVersion(Int)
    case cacheCorrupted
    
    public var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "尚未設定 API 連線端點。"
        case .invalidEndpoint:
            return "API 連線端點格式錯誤，必須是有效的 HTTPS 網址。"
        case .transport(let error):
            return "網路連線失敗，請檢查網路連線：\(error.localizedDescription)"
        case .tls:
            return "安全性驗證（TLS）失敗。若使用本機自簽憑證，請確認 iPhone 已安裝並完整信任該 CA。"
        case .httpStatus(let code):
            return "伺服器回應錯誤 (HTTP \(code))。"
        case .decoding(let error):
            return "資料解析失敗：\(error.localizedDescription)"
        case .unsupportedSchemaVersion(let version):
            return "資料格式版本不相容 (版本: \(version))，請更新 App。"
        case .cacheCorrupted:
            return "本機快取資料損壞。"
        }
    }
}
