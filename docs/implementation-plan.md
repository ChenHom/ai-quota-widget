# AIQuota iPhone App 與 Widget 實作規劃

最後更新：2026-07-16

相關文件：[產品規格](specification.md) · [工作清單](tasks.md)

## 1. 目標

建立原生 iPhone App 與 Widget，讀取 Collector 發布的 HTTPS `quota.json`，顯示 Codex、Claude、AGY 的 `5h`／`7d` 剩餘額度、重置時間、資料狀態與最後更新時間。

本專案參考 `/Users/hom/code/ai/ai-quota` 的資料格式與安全邊界，但針對 iOS 與 WidgetKit 的執行模型重新設計：

- 不直接連接 Provider，也不保存 Provider 帳密、Cookie 或 access token。
- 保留 Collector → 靜態 `quota.json` → Client 的資料流。
- 主 App 與 Widget Extension 共用資料模型、網路存取、快取與顯示規則。
- Widget 以「快速掃讀」為主；設定、詳細錯誤與手動診斷放在主 App。
- 第一版不承諾每 5 分鐘更新。Widget 實際更新時間由 WidgetKit 排程與系統預算決定。

## 2. 第一版範圍

### 包含

- iPhone 主 App。
- `systemMedium` Home Screen Widget。
- Codex、Claude、AGY 三個 Provider。
- 每個 Provider 顯示 `5h`、`7d` 剩餘百分比。
- 有資料時顯示重置時間。
- 顯示資料新鮮度與最後同步時間。
- App 內設定 HTTPS endpoint。
- App 內手動重新整理。
- Widget timeline 更新時嘗試取得遠端資料。
- App Group 共享最後成功資料。
- 網路失敗時顯示快取並標示資料過期。
- 支援 Home Screen 的 Light、Dark、Clear 與 Tinted 外觀。

### 第一版不包含

- Provider 登入、OAuth 或 token 管理。
- Collector 實作或部署。
- 推播更新。
- Live Activity。
- Lock Screen Widget。
- Apple Watch complication。
- `systemSmall` 與其他 Widget 尺寸。
- 在 Widget 中顯示完整網路錯誤或診斷資訊。
- 強制 Widget 永遠顯示 Liquid Glass；Widget 外觀由使用者的系統設定控制。

## 3. 系統架構

```text
各 Provider 額度來源
        ↓
Collector（目前每 5 分鐘產生資料）
        ↓
quota.json（HTTPS）
        ↓
QuotaAPIClient
        ↓
QuotaRepository ─────→ App Group Cache
        │                       │
        ├──→ iPhone App         └──→ Widget TimelineProvider
        │       ↓                         ↓
        │   App 顯示層                QuotaEntry
        │                                 ↓
        └──────────────────────────→ Widget 顯示層
```

程式分成「資料層」與「顯示層」。WidgetKit 的 `TimelineProvider` 是兩層之間的系統轉接點，不包含畫面排版，也不重複實作網路與解碼邏輯。

## 4. 資料層

### 4.1 資料模型

沿用參考專案的 JSON 契約：

```swift
struct QuotaResponse: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: Date
    let providers: [String: ProviderQuota]
}

struct ProviderQuota: Codable, Sendable {
    let provider: String
    let status: String
    let lastSuccessAt: Date
    let windows: QuotaWindows
}

struct QuotaWindows: Codable, Sendable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
}

struct UsageWindow: Codable, Sendable {
    let remainingPercent: Double
    let resetsAt: Date?
}
```

實作要求：

- `five_hour`、`seven_day` 與 `resetsAt` 必須允許 `null`。
- 不把缺少資料解讀為 `0%`。
- 顯示前可將百分比限制在 `0...100`，但保留原始解碼值供診斷。
- 驗證支援的 `schemaVersion`；不支援時回報明確錯誤並保留舊快取。
- ISO 8601 解碼同時支援有／無 fractional seconds。

### 4.2 QuotaAPIClient

職責：

- 建立 HTTPS `URLRequest`。
- timeout 初始值為 15 秒。
- 使用 `reloadIgnoringLocalCacheData` 與 `Cache-Control: no-cache`。
- 僅接受 HTTP `2xx`。
- 解碼 `QuotaResponse`。
- 將傳輸、HTTP、解碼與 schema 錯誤轉成型別化錯誤。

介面草案：

```swift
protocol QuotaFetching: Sendable {
    func fetchQuota(from endpoint: URL) async throws -> QuotaResponse
}
```

### 4.3 QuotaCache

使用 App Group shared container，使主 App 與 Widget Extension 能讀寫同一份最後成功資料。

建議格式：原子寫入的小型 JSON 檔，而非資料庫。快取內容包含：

```swift
struct CachedQuota: Codable, Sendable {
    let quota: QuotaResponse
    let fetchedAt: Date
}
```

規則：

- 只有遠端資料通過 HTTP、解碼與 schema 驗證後才能覆寫快取。
- 寫檔採原子替換，避免 Widget 讀到半份資料。
- 讀取損壞快取時視為無快取，不讓 extension crash。
- endpoint 不寫入快取檔，改存於 App Group `UserDefaults`。
- endpoint 本身不是秘密；若未來增加驗證 token，必須改用共享 Keychain access group。

### 4.4 QuotaRepository

Repository 統一遠端與快取策略，主 App 與 Widget 不自行決定 fallback。

```swift
protocol QuotaRepositoryProtocol: Sendable {
    func latestQuota() async -> QuotaLoadResult
    func cachedQuota() async -> CachedQuota?
}

enum QuotaLoadResult: Sendable {
    case fresh(CachedQuota)
    case cached(CachedQuota, reason: QuotaLoadFailure)
    case unavailable(QuotaLoadFailure)
}
```

流程：

1. 讀取 endpoint。
2. endpoint 缺失時直接讀快取。
3. 嘗試下載並驗證遠端資料。
4. 成功時寫入快取並回傳 `.fresh`。
5. 失敗且有快取時回傳 `.cached`。
6. 失敗且無快取時回傳 `.unavailable`。

### 4.5 時間與資料即時性

必須區分：

- `generatedAt`：Collector 產生整份 JSON 的時間。
- `lastSuccessAt`：個別 Provider 最後成功取得資料的時間。
- `fetchedAt`：iPhone 最後成功下載 JSON 的時間。
- Timeline entry 的 `date`：WidgetKit 顯示該 entry 的時間。

第一版即時性規則：

| 年齡（以 `generatedAt` 計算） | 顯示狀態 | Widget 表現 |
|---|---|---|
| 0–15 分鐘 | fresh | 正常顯示 |
| 15–60 分鐘 | delayed | 顯示橘色延遲提示 |
| 超過 60 分鐘 | stale | 顯示明確過期提示，但保留數值 |
| 無資料 | unavailable | 引導使用者開啟 App 設定或重試 |

Provider 自身的 `status` 與 `lastSuccessAt` 仍需獨立顯示；整份 JSON 即時性不代表每個 Provider 都正常。

## 5. 顯示層

### 5.1 共用顯示模型

不要讓 View 直接理解原始 status 字串或自行計算 stale。建立純值型別供 App 與 Widget 共用：

```swift
struct QuotaDisplayState: Sendable {
    let providers: [ProviderDisplayState]
    let freshness: FreshnessState
    let generatedAt: Date?
    let fetchedAt: Date?
}
```

共用內容包括：

- Provider 固定順序與顯示名稱。
- 百分比格式。
- `MM/dd HH:mm` 重置時間格式。
- 相對更新時間。
- fresh／delayed／stale／unavailable 判斷。
- `ok` 與其他 Provider status 的顯示文字、圖示及語意色。

### 5.2 主 App

主 App 負責完整資訊與設定：

- 三個 Provider 的完整卡片。
- `5h`／`7d` 百分比與重置時間。
- Collector 與 Provider 最後更新時間。
- 手動重新整理及 loading 狀態。
- endpoint 設定與 HTTPS 格式驗證。
- 本機網路、TLS、HTTP、解碼與 schema 錯誤的可理解訊息。
- 更新成功後呼叫 `WidgetCenter.shared.reloadTimelines(ofKind:)`。

主 App 可使用 `@Observable`／`ObservableObject` ViewModel；資料層本身不依賴 SwiftUI。

### 5.3 Medium Widget

第一版只支援 `systemMedium`，一次顯示三個 Provider：

```text
AI QUOTA                         12 分鐘前

Codex    5h  ███████░ 82%    7d  ████░░░ 54%
Claude   5h  █████░░░ 63%    7d  ██████░ 78%
AGY      5h  ███░░░░░ 41%    7d  ───────  —
```

版面原則：

- 快速掃讀優先，不顯示長錯誤訊息。
- 缺值顯示 `—`，不可顯示 `0%`。
- 重置時間空間不足時放到主 App；Medium Widget 優先保留百分比與即時性。
- 整張 Widget 點擊後 deep link 到主 App dashboard。
- VoiceOver label 必須包含 Provider、視窗、剩餘百分比與資料狀態。
- Dynamic Type 放大時避免文字截斷重要百分比。

### 5.4 Liquid Glass 與 Widget 外觀

Widget 的整體玻璃背景交給 WidgetKit，而不是複製 macOS 的 `NSPanel + glassEffect`。

實作原則：

- 使用 `.containerBackground(for: .widget)` 宣告可移除的 Widget 背景。
- Light／Dark full-color 模式提供低干擾的深／淺背景。
- 使用者選擇 Clear 外觀時，由系統移除自訂背景並替換成 Liquid Glass。
- 使用者選擇 Tinted 外觀時，由系統套用 tint。
- 重要百分比、進度或狀態可使用 `.widgetAccentable()`。
- Provider 區塊不各自疊加 `.glassEffect()`，避免雙層玻璃與可讀性問題。
- 在 Light、Dark、Clear、Tinted 四種外觀實機驗證。
- 支援 Reduce Transparency、Increase Contrast 與不同桌布亮度。

參考：

- [Optimizing your widget for accented rendering mode and Liquid Glass](https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass)
- [Displaying the right widget background](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background)
- [Widgets — Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/widgets)

## 6. Widget 更新策略

不能將 macOS `QuotaStore` 的常駐 5 分鐘 loop 搬到 Widget Extension。WidgetKit 根據使用情況、可見性與系統資源分配更新預算，timeline 的日期是請求時間，不是準時執行保證。

第一版策略：

- `placeholder`：使用固定假資料，只供 gallery skeleton。
- `snapshot`：優先讀快取；沒有快取時使用範例資料或未設定狀態。
- `timeline`：呼叫 Repository 嘗試遠端更新，再以結果建立單一 entry。
- refresh policy 初始設定為 `.after(now + 30 minutes)`。
- 系統延後更新時，仍以快取與 stale 標記維持可用畫面。
- 主 App 成功更新後，僅在顯示內容實際變更時要求 reload timeline。
- 第一版不加入 push update；實測 30 分鐘策略不足時再評估 WidgetKit push notifications。

參考：

- [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)
- [Making network requests in a widget extension](https://developer.apple.com/documentation/widgetkit/making-network-requests-in-a-widget-extension)

## 7. endpoint、網路與安全

- 僅接受具 host 的 `https` URL。
- 不在 repository、測試 fixture、log 或畫面截圖中提交實際內網 URL。
- 不停用 TLS server trust 驗證。
- 使用 mkcert 時，實機 iPhone 必須安裝並完整信任對應 CA，憑證 SAN 必須涵蓋實際 hostname。
- endpoint 位於 LAN 時，App 必須提供本機網路用途說明並以實機測試權限流程。
- 離開 LAN 後 Widget 可能只能顯示快取；未來若要求外網更新，優先評估受保護的公開 HTTPS endpoint 或 VPN／Tailscale。
- Log 不記錄完整 payload、私人 endpoint、憑證或未來可能加入的 token。

## 8. 建議目錄與 targets

```text
ai-quota-widget/
├── AIQuota.xcodeproj
├── AIQuotaApp/
│   ├── App/
│   ├── Presentation/
│   │   ├── Dashboard/
│   │   └── Settings/
│   ├── Assets.xcassets
│   └── Info.plist
├── AIQuotaWidgetExtension/
│   ├── AIQuotaWidget.swift
│   ├── QuotaTimelineProvider.swift
│   ├── QuotaEntry.swift
│   ├── MediumQuotaWidgetView.swift
│   ├── Assets.xcassets
│   └── Info.plist
├── Shared/
│   ├── Data/
│   │   ├── Models/
│   │   ├── Remote/
│   │   ├── Persistence/
│   │   └── Repository/
│   ├── Presentation/
│   └── Configuration/
├── AIQuotaTests/
│   ├── Fixtures/
│   ├── Data/
│   └── Presentation/
└── docs/
    └── implementation-plan.md
```

第一版可讓 `Shared` 原始檔同時加入 App 與 Widget targets。若共用模組變大，再抽成本地 Swift Package；初期不為模組化增加額外建置複雜度。

需要的 targets：

1. `AIQuotaApp`：iOS Application。
2. `AIQuotaWidgetExtension`：Widget Extension。
3. `AIQuotaTests`：共用資料與顯示規則單元測試。

App 與 Widget Extension 必須使用同一 App Group entitlement。

## 9. 實作階段

### 階段 1：專案骨架與資料契約

- 建立 iOS App、Widget Extension 與 test targets。
- 設定 deployment target、bundle IDs 與 App Group。
- 搬移並調整 Codable／Sendable 資料模型。
- 建立匿名化 JSON fixtures。
- 完成日期與 Optional 欄位解碼測試。

完成條件：fixture 可正確解碼，缺值不會被轉成 0，App 與 Widget targets 都能編譯共用模型。

### 階段 2：資料存取與共享快取

- 實作 endpoint configuration。
- 實作 `QuotaAPIClient`。
- 實作 App Group 原子 JSON cache。
- 實作 `QuotaRepository` fallback。
- 完成 HTTP、解碼、schema、快取損壞與離線測試。

完成條件：遠端成功會更新快取；斷網、HTTP 失敗與 JSON 損壞時能安全回退。

### 階段 3：主 App

- 建立 dashboard 與設定畫面。
- 加入手動重新整理與 loading 狀態。
- 顯示完整錯誤與 freshness。
- 更新成功後通知 WidgetKit reload。

完成條件：實機可設定 endpoint、取得資料、重啟後讀到快取，錯誤訊息可用於診斷。

### 階段 4：Medium Widget

- 實作 placeholder、snapshot、timeline。
- 實作三 Provider Medium 版面。
- 加入 deep link、accessibility 與 stale 狀態。
- 使用 30 分鐘 `.after` policy。

完成條件：Widget 可從遠端或快取顯示資料；無 endpoint、離線與過期情境均不空白或 crash。

### 階段 5：外觀與實機驗證

- 驗證 Light、Dark、Clear、Tinted。
- 驗證 Reduce Transparency 與 Increase Contrast。
- 驗證不同桌布、Dynamic Type 與 VoiceOver。
- 驗證 LAN、離線、TLS 失敗與離開 LAN 的行為。
- 在未連接 Xcode debugger 的情況下觀察 timeline 更新。

完成條件：Widget 在所有外觀下資訊可讀，資料過期標示正確，系統延後更新不會造成錯誤狀態。

## 10. 測試計畫

### 單元測試

- 有／無 fractional seconds 的 ISO 8601 日期。
- `five_hour`、`seven_day`、`resetsAt` 為 `null`。
- 不支援的 `schemaVersion`。
- 百分比超出 `0...100` 的顯示限制。
- Provider 固定排序與缺少 Provider。
- fresh／delayed／stale 邊界值。
- 遠端成功、遠端失敗加有效快取、完全無資料。
- 損壞快取不造成 crash。

### UI 與 snapshot 驗證

- Medium Widget 的正常、部分缺值、Provider 延遲、整體 stale、無資料狀態。
- Light、Dark、Clear、Tinted。
- 中文與較長文字。
- Dynamic Type 與 VoiceOver。

### 實機驗證

- 首次本機網路權限。
- mkcert CA 未信任／已信任。
- Wi-Fi、行動網路、飛航模式。
- App 更新後 Widget reload。
- Widget 自行 timeline 更新與系統延後情況。
- App 與 extension 被終止後仍能讀取快取。

## 11. 第一版驗收條件

- 使用者能在 App 中設定有效的 HTTPS endpoint。
- App 能顯示三個 Provider 的 `5h`／`7d` 額度與資料狀態。
- Widget 能一次快速掃讀三個 Provider。
- 缺少額度視窗時顯示 `—`，不誤顯示 `0%`。
- 遠端失敗時，若有快取便持續顯示並標記 delayed／stale。
- 無 endpoint 或無任何資料時，Widget 提供可理解的開啟 App 引導。
- 主 App 與 Widget 不保存 Provider secrets，也不降低 TLS 驗證。
- Clear 外觀由系統呈現 Liquid Glass，Light／Dark／Tinted 仍保持可讀。
- Widget 不依賴每 5 分鐘準時執行。
- 所有核心資料層與 freshness 規則都有單元測試。

## 12. 後續候選功能

第一版穩定後依需求排序：

1. `systemSmall`：透過 App Intent 選擇單一 Provider。
2. Widget 互動式重新整理按鈕。
3. Lock Screen Widget：顯示最低剩餘額度或 stale 狀態。
4. WidgetKit push notifications。
5. 多 endpoint／多環境設定。
6. Apple Watch Smart Stack／complication。
7. 將共享程式抽成本地 Swift Package。

## 13. 尚待決策

- 第一版最低支援的 iOS 版本。
- 正式 bundle ID 與 App Group ID。
- endpoint 只由使用者輸入，或提供 QR code／configuration profile 匯入。
- full-color 模式的背景風格：延續 macOS 煙燻深色，或採用跟隨 light／dark 的雙版本。
- 外網存取是否列入第一版需求；若是，需先確定網路與 TLS 部署方案。
