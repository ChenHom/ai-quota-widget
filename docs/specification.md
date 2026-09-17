# AIQuota iPhone App 與 Widget 產品規格

版本：0.1 Draft
最後更新：2026-07-16
相關文件：[實作規劃](implementation-plan.md) · [工作清單](tasks.md)

## 1. 文件目的

本文件定義 AIQuota iPhone App 與 Home Screen Widget 第一版的可實作、可測試與可驗收行為。

文件中的關鍵字：

- **必須**：第一版驗收不可缺少。
- **應該**：原則上實作；若取消必須留下決策記錄。
- **可以**：不影響第一版驗收的選配功能。

## 2. 產品摘要

AIQuota 是只讀型額度檢視工具。它從使用者設定的 HTTPS endpoint 取得 Collector 所產生的 `quota.json`，在 iPhone App 與 Widget 顯示 Codex、Claude、AGY 的額度。

產品必須維持下列安全邊界：

- 不直接呼叫 Provider 額度 API。
- 不要求或保存 Provider 帳密、Cookie、access token、refresh token 或 API key。
- 不停用 TLS 憑證或 hostname 驗證。
- 不將實際私人 endpoint 寫入原始碼、測試資料或版本控制。

## 3. 使用者情境

### US-001 初次設定

使用者開啟 App、輸入 HTTPS endpoint、執行連線測試並保存。成功後 App 顯示額度，Widget 可透過共享設定與快取顯示相同資料。

### US-002 快速查看

使用者在 Home Screen 查看 Medium Widget，不開啟 App即可快速比較三個 Provider 的 `5h`／`7d` 剩餘百分比。

### US-003 手動更新

使用者在 App 內要求重新整理。成功後 App 更新畫面、寫入共享快取，並要求 WidgetKit 重新載入相關 timeline。

### US-004 離線或服務失敗

遠端資料無法取得時，App 與 Widget 繼續顯示最後成功資料，並清楚標示資料延遲或過期。

### US-005 尚未設定

沒有 endpoint 且沒有快取時，App 顯示設定引導；Widget 顯示簡短引導並可點擊開啟 App。

## 4. 第一版範圍

### 4.1 必須提供

- 原生 iPhone App。
- Widget Extension。
- `systemMedium` Home Screen Widget。
- App 內 endpoint 設定、驗證與手動重新整理。
- Codex、Claude、AGY 三個 Provider。
- `5h`／`7d` 剩餘百分比。
- 主 App 中的重置時間、Provider 狀態與資料時間。
- App Group 共用設定與最後成功快取。
- 遠端失敗時的快取 fallback。
- fresh、delayed、stale、unavailable 四種顯示狀態。
- Light、Dark、Clear、Tinted 外觀適配。
- VoiceOver 與 Dynamic Type 基本支援。

### 4.2 第一版不提供

- Provider 驗證資訊管理。
- Collector 建置或部署。
- `systemSmall`、Lock Screen、Apple Watch Widget。
- Live Activity。
- Push-based Widget update。
- 多 endpoint。
- Widget 的多帳號版面（`systemMedium` 放不下第四列，Widget 只顯示各 Provider 的預設帳號；App Dashboard 已顯示所有帳號）。
- 保證固定時間或每 5 分鐘更新 Widget。
- Widget 中的完整錯誤診斷。

## 5. 資料契約

### 5.1 JSON 範例

對應 collector 端 schema v2（2026-09-16 起伺服器只輸出 v2，v1 不再提供）。
`providers` 底下每個 Provider 是「一帳號一元素」的陣列。

```json
{
  "schemaVersion": 2,
  "generatedAt": "2026-09-16T02:56:34.538Z",
  "providers": {
    "codex": [
      {
        "provider": "codex",
        "account": "main",
        "status": "ok",
        "confidence": "experimental",
        "source": "chatgpt.com/backend-api/wham/usage",
        "lastSuccessAt": "2026-09-16T02:56:34.538Z",
        "windows": {
          "five_hour": {
            "usedPercent": 17.6,
            "remainingPercent": 82.4,
            "resetsAt": "2026-09-16T07:30:11.000Z"
          },
          "seven_day": {
            "usedPercent": 46.0,
            "remainingPercent": 54.0,
            "resetsAt": null
          }
        },
        "resetCredits": {
          "availableCount": 2,
          "applicableAvailableCount": 1,
          "credits": [
            {
              "status": "available",
              "grantedAt": "2026-09-04T01:39:45.503Z",
              "expiresAt": "2026-10-04T01:39:45.503Z"
            }
          ]
        }
      }
    ],
    "claude": [
      { "provider": "claude", "account": "main", "status": "ok", "...": "..." },
      { "provider": "claude", "account": "work", "status": "ok", "...": "..." }
    ]
  }
}
```

### 5.2 欄位規格

| 欄位 | 型別 | 必要 | 規則 |
|---|---|---:|---|
| `schemaVersion` | Integer | 是 | 只接受 `2`；其餘一律視為不可用 |
| `generatedAt` | ISO 8601 Date | 是 | 支援有／無小數秒 |
| `providers` | Object | 是 | key 為 Provider 識別字，value 為帳號陣列 |
| `providers.<key>` | Array | 是 | 至少 1 個元素；`agy` 可能整個缺席 |
| `provider` | String | 是 | 顯示名稱不可直接依賴此原始值 |
| `account` | String | 是 | 帳號標籤，同 Provider 內唯一；預設帳號固定叫 `main` |
| `status` | String | 是 | `ok` 為正常；未知值視為非正常但不可解碼失敗 |
| `confidence` | String | 否 | 目前不解碼、不顯示 |
| `source` | String | 否 | 上游端點；目前不解碼、不顯示 |
| `lastSuccessAt` | ISO 8601 Date 或 null | 是 | Provider 最後成功時間；null 不可造成解碼失敗 |
| `five_hour` | Object 或 null | 是 | 缺值不可轉成 0% |
| `seven_day` | Object 或 null | 是 | 缺值不可轉成 0%；agy 恆為 null |
| `usedPercent` | Double | 否 | 與 `remainingPercent` 互補；目前不解碼、不顯示 |
| `remainingPercent` | Double | 是 | 顯示時限制於 0–100；保留原始值供診斷 |
| `resetsAt` | ISO 8601 Date 或 null | 是 | null 顯示為 `—` 或省略 |
| `resetCredits` | Object 或 null 或缺 | 否 | 重置券；缺欄位、null 或 `availableCount` 為 0 時完全不顯示 |
| `availableCount` | Integer | 是（在 `resetCredits` 內） | 徽章顯示的張數 |
| `applicableAvailableCount` | Integer | 否 | 與 `availableCount` 的語意差異未定，暫不解碼、不顯示 |
| `credits` | Array | 是（在 `resetCredits` 內） | 每筆含 `status`／`grantedAt`／`expiresAt` |
| `expiresAt` | ISO 8601 Date 或 null | 是（在 `credits` 內） | 固定以 Asia/Taipei 顯示；null 顯示為 `—` |

### 5.2.1 帳號選取

- 陣列順序為伺服器設定順序，`main` 保證排在最前，但消費端必須以 `account` 比對而非依賴索引。
- App Dashboard 一個帳號一列，同一個 Provider 內沿用伺服器順序。
- Widget 只取預設帳號：先找 `account == "main"`，找不到才退回第一個元素。
- 顯示層的列 id 必須是 `provider/account` 複合鍵；多列共用同一個 id 會讓 `ForEach` 的 `Identifiable` 撞號。

### 5.3 Provider 順序

顯示層必須使用固定順序：

1. `codex` → `Codex`
2. `claude` → `Claude`
3. `agy` → `AGY`

JSON 缺少某個 Provider 時仍保留其顯示位置並顯示 `—`。JSON 出現未知 Provider 時，第一版忽略但不可造成解碼失敗。

同一個 Provider 的多個帳號在 App Dashboard 上依序排在該 Provider 的位置，預設帳號（`main`）在最前。單帳號時不顯示帳號標籤，外觀與 schema v1 時相同。

## 6. Endpoint 與設定規格

### CFG-001 Endpoint 驗證

Endpoint 必須：

- 可由 `URL` 解析。
- scheme 為 `https`。
- 具有非空 host。

不符合規格時不得保存，並顯示可理解的欄位錯誤。

### CFG-002 Endpoint 儲存

- Endpoint 必須存於 App Group `UserDefaults`。
- App 與 Widget Extension 必須讀取相同 key。
- UI 與一般 log 不應顯示 query、fragment 或可能包含秘密的完整 URL。

### CFG-003 連線測試

- 使用者必須能在設定畫面測試 endpoint。
- 測試必須完成實際 HTTP request、狀態碼、schema 與 JSON 解碼驗證。
- 測試成功後才允許將新 endpoint 視為有效設定。
- 若產品選擇允許「先保存、稍後測試」，必須在實作前以決策記錄修改本條。

## 7. 資料取得與快取規格

### DATA-001 HTTP request

- 使用 `URLSession`。
- timeout 為 15 秒。
- cache policy 為 `reloadIgnoringLocalCacheData`。
- request header 包含 `Cache-Control: no-cache`。
- 只接受 HTTP `200...299`。

### DATA-002 解碼

- 解碼器必須支援有／無 fractional seconds 的 ISO 8601 日期。
- 不支援的 `schemaVersion` 必須產生獨立錯誤類型。
- `schemaVersion` 檢查必須早於完整解碼：跨版本連 `providers` 的形狀都會變，先解碼會讓版本不符表現成解碼錯誤。
- 未知 Provider status 不得使整份資料解碼失敗。

### DATA-003 快取

最後成功資料必須以以下邏輯結構存入 App Group shared container：

```swift
struct CachedQuota: Codable, Sendable {
    let quota: QuotaResponse
    let fetchedAt: Date
}
```

- 快取必須以原子檔案替換寫入。
- 僅驗證成功的遠端資料可以覆寫快取。
- 損壞或不相容快取必須視為不存在，不得 crash。
- endpoint 變更成功後，舊快取必須清除，避免顯示另一來源的舊資料。

### DATA-004 Repository fallback

Repository 必須產生以下結果之一：

| 結果 | 條件 | 顯示資料 |
|---|---|---|
| `fresh` | 遠端取得與驗證成功 | 新資料 |
| `cached` | 遠端失敗且有效快取存在 | 最後快取與失敗原因 |
| `unavailable` | 遠端失敗且無有效快取 | 無資料狀態 |

若 endpoint 缺失但快取存在，必須回傳 `cached` 並附帶未設定原因。

### DATA-005 並行請求

- 同一 process 不應同時執行多個等價刷新請求。
- App 手動刷新期間再次觸發刷新時，應共用現有工作或忽略重複觸發。
- App 與 Widget 可能跨 process 同時寫快取；原子替換必須確保讀者只得到完整舊版或新版。

## 8. 新鮮度與狀態規格

### 8.1 時間定義

- `generatedAt`：Collector 產生整份資料的時間。
- `lastSuccessAt`：Provider 最後成功時間。
- `fetchedAt`：裝置成功下載該資料的時間。
- `entry.date`：WidgetKit timeline entry 生效時間。

四者不得混用。

### 8.2 整體新鮮度

新鮮度以 `now - generatedAt` 計算；若 `generatedAt` 位於未來，年齡先限制為 0，並可留下診斷訊息。

| 年齡 | 狀態 | 語意 |
|---|---|---|
| `< 15 分鐘` | `fresh` | 資料正常 |
| `>= 15 且 < 60 分鐘` | `delayed` | 資料可能延遲 |
| `>= 60 分鐘` | `stale` | 資料已過期 |
| 無可顯示資料 | `unavailable` | 無資料 |

邊界時間必須由注入的 clock 測試，不可讓單元測試依賴真實現在時間。

### 8.3 Provider 狀態

- `status == "ok"`：正常。
- 其他或未知值：資料延遲。
- Provider status 與整體 freshness 必須分開計算。
- Provider 缺失：無資料。

## 9. 主 App 功能規格

### APP-001 Dashboard

Dashboard 必須顯示：

- Codex、Claude、AGY，依固定順序排列。
- 每個 Provider 的 `5h`、`7d` 百分比。
- 每個 window 的重置時間；缺值顯示 `—`。
- Provider 最後成功時間與狀態。
- 整份資料的 freshness。
- 最後成功下載時間。

### APP-002 重新整理

- Dashboard 必須提供重新整理按鈕。
- 請求進行中必須顯示 loading 並避免重複觸發。
- 遠端成功後必須更新畫面與快取。
- 顯示內容實際改變後，必須要求 WidgetKit reload 對應 kind。
- 遠端失敗且有快取時，必須保留數值並顯示非阻斷式錯誤。

### APP-003 空狀態

- 無 endpoint、無資料時顯示設定 CTA。
- endpoint 存在但無法取得任何資料時，顯示重試與設定入口。
- 不得只顯示 Foundation 原始錯誤字串。

### APP-004 Settings

設定畫面必須提供：

- Endpoint 輸入欄位。
- 格式驗證。
- 連線測試。
- 保存成功／失敗回饋。
- 本機網路與私人 CA 的簡短排錯提示。

### APP-005 Deep link

點擊 Widget 必須開啟 Dashboard。第一版使用的 deep link route 為 `aiquota://dashboard`；正式 URL scheme 必須與 bundle 設定一致。

## 10. Widget 功能規格

### WID-001 支援尺寸

第一版 Widget 必須只宣告 `.systemMedium`。其他尺寸不得出現在 gallery。

### WID-002 內容

Medium Widget 必須顯示：

- 標題 `AI QUOTA`。
- 相對更新時間或 freshness 提示。
- Codex、Claude、AGY 三列。
- 每列的 `5h` 與 `7d` 百分比。
- delayed／stale／unavailable 的簡短視覺提示。

第一版 Medium Widget 不顯示重置時間；重置時間由主 App 顯示，以確保三個 Provider 與兩個 window 在 Dynamic Type 下仍可讀。

### WID-003 缺值

- 缺少 window 時顯示 `—`，不可顯示空進度或 `0%`。
- 缺少 Provider 時仍保留該列。
- 有快取時即使遠端失敗也不得用整張錯誤畫面取代數值。

### WID-004 TimelineProvider

- `placeholder` 不得發出網路請求或讀取私人資料。
- `snapshot` 優先讀快取；無快取時提供 gallery 範例或未設定狀態。
- `timeline` 必須透過 Repository 嘗試取得最新資料。
- 第一版建立單一 entry，refresh policy 為 `.after(now + 30 minutes)`。
- 30 分鐘是最早要求時間，不可在產品文字中承諾準時更新。

### WID-005 互動

- 整張 Widget 必須 deep link 至 Dashboard。
- 第一版不提供 Widget 內重新整理按鈕。

## 11. Widget 外觀規格

### VIS-001 背景

- Widget 根 View 必須使用 `.containerBackground(for: .widget)`。
- 背景必須維持可移除，以支援系統 Clear、Tinted 與其他需要移除背景的 context。
- 不得以 `.containerBackgroundRemovable(false)` 強制保留背景。

### VIS-002 Liquid Glass

- Clear 外觀的 Liquid Glass 由系統產生。
- 產品不得宣稱 App 能強制使用者的 Widget 永遠顯示 Clear Glass。
- Provider 列不得各自疊加 `.glassEffect()`。
- full-color Light／Dark 模式必須提供可讀的自訂背景。

### VIS-003 Rendering mode

- 必須在 full-color、accented、vibrant 相關環境保持主要數值可讀。
- 重要百分比或進度可以加入 `.widgetAccentable()`。
- 不得只以顏色傳達 fresh／delayed／stale 狀態。

## 12. 錯誤規格

資料層至少必須區分：

| 類別 | 範例 | App 呈現 | Widget 呈現 |
|---|---|---|---|
| Configuration | endpoint 缺失／無效 | 設定引導 | 開啟 App |
| Transport | offline、timeout、DNS | 簡短說明與重試 | 快取加 stale 標記 |
| TLS | CA 不信任、hostname 不符 | TLS 排錯提示 | 快取加 stale 標記 |
| HTTP | 非 2xx | 狀態錯誤與重試 | 快取加 stale 標記 |
| Decoding | JSON 不相容 | 資料格式錯誤 | 快取加 stale 標記 |
| Schema | 版本不支援 | 版本不相容 | 快取加 stale 標記 |
| Cache | 檔案損壞 | 忽略並重新取得 | 無資料狀態 |

錯誤訊息不得包含私人 endpoint 全文或 response payload。

## 13. Accessibility 與本地化

- Provider 名稱、window、百分比與狀態必須有 VoiceOver label。
- `—` 的 VoiceOver 說明應為「沒有資料」，不可朗讀為符號名稱。
- 重要狀態不得只靠紅、綠、橘顏色區分。
- App 必須支援 Dynamic Type；Widget 必須在系統允許的字級環境避免重要百分比被截斷。
- 第一版介面文字使用繁體中文；字串應放在可本地化資源中。
- 日期顯示沿用 `MM/dd HH:mm`；相對時間使用系統 formatter。

## 14. 安全與隱私

- 正式版只能接受 HTTPS endpoint。
- 不實作接受所有 server trust challenge 的 delegate。
- 不放寬 ATS 來繞過 TLS 問題。
- 私人 CA 必須由裝置層安裝與信任。
- App 需要存取 LAN 時必須提供本機網路用途說明。
- Source、fixture、log、screenshot 與 crash metadata 不得包含實際私人 URL 或秘密。
- Widget placeholder 與 gallery snapshot 必須使用匿名範例資料。

## 15. 效能與可靠性

- Widget view 不得執行網路、檔案或昂貴計算；所有資料在 entry 建立前準備完成。
- Widget 必須能在無網路、無 App process 與 extension 重啟後從共享快取恢復。
- 所有 View 輸入應為不可變值型別。
- 資料層不得依賴 SwiftUI。
- 網路或快取錯誤不得造成 App 或 Widget crash。
- 不得建立常駐 5 分鐘 timer 企圖控制 Widget 更新。

## 16. 驗收案例

| ID | 前置狀態 | 操作 | 預期結果 |
|---|---|---|---|
| AC-001 | 無 endpoint、無快取 | 開啟 App | 顯示設定引導 |
| AC-002 | 無 endpoint、無快取 | 加入 Widget | 顯示開啟 App 引導 |
| AC-003 | 有效 endpoint | App 手動更新 | 顯示新資料、寫快取、要求 Widget reload |
| AC-004 | 遠端離線、有快取 | 更新 | 保留數值並顯示 delayed／stale |
| AC-005 | 遠端離線、無快取 | 更新 | 顯示 unavailable 與重試／設定入口 |
| AC-006 | window 為 null | 顯示 App／Widget | 顯示 `—`，不顯示 `0%` |
| AC-007 | JSON 缺少 Claude | 顯示 Medium Widget | Claude 列保留並顯示無資料 |
| AC-008 | 不支援 schema | 更新 | 保留舊快取並回報版本不相容 |
| AC-009 | Clear 外觀 | 查看 Widget | 系統玻璃背景且主要內容可讀 |
| AC-010 | Tinted 外觀 | 查看 Widget | 系統 tint 下百分比與狀態可辨識 |
| AC-011 | 快取檔損壞 | 啟動 App／Widget | 不 crash，視為無快取並嘗試恢復 |
| AC-012 | endpoint 變更成功 | 重新整理 | 不顯示舊 endpoint 的快取資料 |

## 17. 已決策項目

下列項目已在建立 Xcode targets 前定案：

- `OPEN-001`：最低 iOS deployment target 設為 **iOS 18**。
- `OPEN-002`：正式 App bundle ID 建議為 **`com.hom.AIQuota`**。
- `OPEN-003`：Widget Extension bundle ID 建議為 **`com.hom.AIQuota.WidgetExtension`**。
- `OPEN-004`：App Group ID 建議為 **`group.com.hom.AIQuota`**。
- `OPEN-005`：full-color 背景採用 **跟隨 Light/Dark 的雙版本背景**。
- `OPEN-006`：分發方式為 **個人開發**。
