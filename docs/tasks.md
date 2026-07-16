# AIQuota iPhone App 與 Widget 工作清單

版本：0.1 Draft
最後更新：2026-07-16
依據：[產品規格](specification.md) · [實作規劃](implementation-plan.md)

## 使用方式

- 每個 task 完成時勾選 checkbox，並確認其「完成條件」。
- `Depends on` 尚未完成時，不應開始會受其決策影響的實作。
- Scope 或規格改變時，先修改 `specification.md`，再調整本清單。
- 不把實機 debugger 下的 Widget 更新頻率當成正式驗收結果。

狀態：

- `[ ]` 未開始
- `[-]` 進行中
- `[x]` 已完成並驗證

## Milestone 0：決策與專案基線

### T-001 決定平台與識別資訊

- [x] 決定最低 iOS deployment target。
- [x] 決定 App bundle ID。
- [x] 決定 Widget Extension bundle ID。
- [x] 決定 App Group ID。
- [x] 決定分發方式：App Store、TestFlight、Ad Hoc 或個人開發。

- Depends on：無
- 完成條件：規格 `OPEN-001...004`、`OPEN-006` 已更新為明確值，且識別資訊沒有使用 `com.example`。

### T-002 決定第一版 full-color 視覺方向

- [x] 選擇固定煙燻深色或 light／dark 雙版本背景。
- [x] 定義 fresh、delayed、stale、unavailable 的圖示與文字表現。
- [x] 保留 Clear／Tinted 由系統控制的原則。

- Depends on：無
- 完成條件：規格 `OPEN-005` 已關閉，留下簡短決策記錄或畫面草圖。

### T-003 建立專案與 targets

- [x] 建立 `AIQuotaApp` iOS App target。
- [x] 建立 `AIQuotaWidgetExtension` Widget Extension target。
- [x] 建立 `AIQuotaTests` unit test target。
- [x] 只讓 Widget 宣告 `.systemMedium`。
- [x] 建立 `Shared`、App、Widget 與 Tests 基本目錄。

- Depends on：T-001
- 完成條件：三個 targets 可在選定的 Xcode／SDK 上建置；App 可啟動；Widget 可出現在 gallery。

### T-004 設定 entitlements 與 capabilities

- [x] App 與 Widget 加入相同 App Group。
- [x] 設定 App／Extension signing。
- [x] 加入本機網路用途說明。
- [x] 設定 `aiquota` URL scheme。
- [x] 確認 Widget deep link 可解析。

- Depends on：T-001、T-003
- 完成條件：App 與 Widget 都能取得 App Group container URL；`aiquota://dashboard` 可開啟 App。

### T-005 建立匿名測試 fixtures

- [x] 建立完整正常資料 fixture。
- [x] 建立 Optional window／`resetsAt: null` fixture。
- [x] 建立缺少 Provider fixture。
- [x] 建立未知 status fixture.
- [x] 建立不支援 schema fixture。
- [x] 確認 fixture 不含實際 endpoint、帳號或秘密。

- Depends on：無
- 完成條件：fixture 覆蓋規格資料契約且通過 secrets 人工檢查。

## Milestone 1：共享資料模型

### T-101 實作 quota Codable models

- [x] 實作 `QuotaResponse`。
- [x] 實作 `ProviderQuota`。
- [x] 實作 `QuotaWindows` 與 snake_case coding keys。
- [x] 實作 `UsageWindow`。
- [x] 所有跨 concurrency boundary 型別符合 `Sendable`。

- Depends on：T-003、T-005
- 完成條件：正常 fixture 能完整解碼並再次編碼；App 與 Widget targets 都可使用 models。

### T-102 實作 ISO 8601 日期解碼

- [x] 支援有 fractional seconds。
- [x] 支援無 fractional seconds。
- [x] 無效日期回傳 decoding error。

- Depends on：T-101
- 完成條件：三種情境均有單元測試且通過。

### T-103 實作 schema validation

- [x] 定義第一版支援的 schema versions。
- [x] 建立 `unsupportedSchemaVersion` 錯誤。
- [x] 未知 Provider status 不觸發 schema 錯誤。

- Depends on：T-101
- 完成條件：不支援 fixture 被拒絕，正常與未知 status fixture 可通過。

## Milestone 2：設定、網路與快取

### T-201 實作 App Group configuration store

- [x] 定義 App Group 與 endpoint key 的集中常數。
- [x] 實作 endpoint 讀取與寫入。
- [x] 實作 HTTPS、host 驗證。
- [x] 防止 log 顯示完整私人 URL。

- Depends on：T-004
- 完成條件：App 寫入的 endpoint 可由 Widget target 測試程式讀取；無效 URL 不可保存。

### T-202 實作 QuotaAPIClient

- [x] 建立 `QuotaFetching` protocol。
- [x] 使用 15 秒 timeout。
- [x] 設定 no-cache request。
- [x] 驗證 HTTP `2xx`。
- [x] 串接日期解碼與 schema validation。
- [x] 分類 transport、TLS、HTTP、decoding、schema 錯誤。

- Depends on：T-102、T-103、T-201
- 完成條件：以 mock URL protocol 或注入 session 測試成功、timeout、非 2xx、壞 JSON 與不支援 schema。

### T-203 實作 CachedQuota 與 QuotaCache

- [x] 實作 `CachedQuota`。
- [x] 取得 App Group container URL。
- [x] 實作原子 JSON 寫入。
- [x] 實作安全讀取。
- [x] 損壞與不相容檔案視為無快取。
- [x] endpoint 成功變更時清除舊快取。

- Depends on：T-004、T-101、T-102
- 完成條件：寫入後 App／Widget 均可讀；中斷或損壞 fixture 不 crash；舊 endpoint 資料不會殘留。

### T-204 實作 QuotaRepository

- [x] 定義 `QuotaLoadResult`。
- [x] 成功時寫快取並回傳 `fresh`。
- [x] 遠端失敗且有快取時回傳 `cached`。
- [x] 無 endpoint 但有快取時回傳 `cached`。
- [x] 完全無資料時回傳 `unavailable`。
- [x] 防止同 process 重複等價刷新。

- Depends on：T-202、T-203
- 完成條件：Repository 決策表所有分支都有單元測試。

## Milestone 3：共用顯示規則

### T-301 實作可注入 Clock

- [x] 定義 production clock。
- [x] 定義測試 fixed clock。
- [x] freshness 計算不直接依賴 `Date.now`。

- Depends on：T-003
- 完成條件：測試可固定 now 並穩定重現所有時間邊界。

### T-302 實作 FreshnessPolicy

- [x] `< 15 分鐘` → fresh。
- [x] `15...<60 分鐘` → delayed。
- [x] `>= 60 分鐘` → stale。
- [x] 未來 `generatedAt` 的年齡限制為 0。
- [x] 無資料 → unavailable。

- Depends on：T-301
- 完成條件：14:59、15:00、59:59、60:00 與未來日期測試通過。

### T-303 實作 QuotaDisplayState mapper

- [x] 固定 Provider 順序與名稱。
- [x] 缺少 Provider 時產生 placeholder state。
- [x] window null 不轉成 0。
- [x] 顯示百分比限制為 0...100。
- [x] Provider status 與整體 freshness 分離。

- Depends on：T-101、T-302
- 完成條件：正常、缺 Provider、缺 window、異常百分比與未知 status 測試通過。

### T-304 實作 formatter 與本地化字串

- [x] 實作 `MM/dd HH:mm` reset formatter。
- [x] 實作相對更新時間。
- [x] 建立繁體中文 strings catalog。
- [x] 為 `—` 提供「沒有資料」無障礙文字。

- Depends on：T-303
- 完成條件：固定 locale／timezone 測試可預測，View 不自行拼接原始 status。

## Milestone 4：iPhone App 顯示層

### T-401 實作 App state／ViewModel

- [x] 串接 Repository 與 DisplayState mapper。
- [x] 管理 initial、loading、loaded、error 狀態。
- [x] 防止重複手動刷新。
- [x] 成功且內容改變時呼叫 WidgetCenter reload。

- Depends on：T-204、T-303
- 完成條件：以 mock repository 測試所有畫面狀態與 reload 條件。

### T-402 實作 Dashboard

- [x] 顯示三個 Provider。
- [x] 顯示 `5h`、`7d` 百分比與進度。
- [x] 顯示 reset time。
- [x] 顯示 Provider status／lastSuccessAt。
- [x] 顯示 generatedAt／fetchedAt freshness。
- [x] 加入重新整理按鈕與 loading。

- Depends on：T-002、T-304、T-401
- 完成條件：APP-001、APP-002 的正常、部分缺值與 cached 狀態可在 preview 或測試中驗證。

### T-403 實作 App 空狀態與錯誤呈現

- [x] 無 endpoint 顯示設定 CTA。
- [x] 無資料顯示重試與設定入口。
- [x] 有快取時使用非阻斷式錯誤。
- [x] 將錯誤類型轉為繁體中文可操作說明。
- [x] TLS 錯誤提供私人 CA／hostname 排錯提示。

- Depends on：T-401、T-402
- 完成條件：規格錯誤表中所有 App 呈現都有 fixture 或 mock 狀態可驗證。

### T-404 實作 Settings

- [x] Endpoint 表單與即時格式驗證。
- [x] 連線測試。
- [x] 測試成功後保存。
- [x] endpoint 變更後清除舊快取並刷新。
- [x] 顯示本機網路與私人 CA 提示。

- Depends on：T-201、T-202、T-203、T-403
- 完成條件：首次設定、無效 URL、連線失敗與成功變更 endpoint 流程可在實機完成。

### T-405 實作 deep link navigation

- [x] 處理 `aiquota://dashboard`。
- [x] App cold start 與 warm start 都導向 Dashboard。
- [x] 未知 route 安全回到預設畫面。

- Depends on：T-004、T-402
- 完成條件：模擬器與實機 cold／warm deep link 測試通過。

## Milestone 5：Medium Widget

### T-501 實作 QuotaEntry

- [x] Entry 只包含 View 所需不可變資料。
- [x] 包含 entry date 與 display state。
- [x] 不將 Repository、URLSession 或可變 store 放入 entry。

- Depends on：T-303
- 完成條件：Entry 為可 safe 傳遞的值型別，Widget View 無需執行 I/O。

### T-502 實作 TimelineProvider

- [x] placeholder 使用匿名範例，不讀私人資料。
- [x] snapshot 優先使用快取。
- [x] timeline 透過 Repository 取得 fresh／cached／unavailable。
- [x] 產生單一 entry。
- [x] policy 設為 `.after(now + 30 minutes)`。

- Depends on：T-204、T-301、T-501
- 完成條件：placeholder、snapshot、有網路、離線有快取、完全無資料測試通過。

### T-503 實作 MediumQuotaWidgetView

- [x] 顯示 `AI QUOTA` 與更新狀態。
- [x] 顯示三個 Provider 固定列。
- [x] 每列顯示 `5h`、`7d` 百分比。
- [x] 缺值顯示 `—`。
- [x] Medium Widget 不顯示 reset time。
- [x] delayed／stale 不只使用顏色表示。

- Depends on：T-002、T-304、T-501
- 完成條件：WID-002、WID-003 所有狀態都有 preview／snapshot 驗證。

### T-504 實作 Widget 背景與 appearance adaptation

- [x] 使用 `.containerBackground(for: .widget)`。
- [x] 保持 container background removable。
- [x] 配置必要的 `.widgetAccentable()`。
- [x] Provider 列不疊加 `.glassEffect()`。
- [x] 支援 Light、Dark、Clear、Tinted。

- Depends on：T-002、T-503
- 完成條件：四種 Home Screen 外觀實機截圖中主要數值皆可讀，Clear 外觀由系統呈現 Liquid Glass。

### T-505 實作 Widget 互動與無障礙

- [x] 整張 Widget deep link 到 Dashboard。
- [x] Provider／window／percentage／status VoiceOver labels。
- [x] 缺值朗讀「沒有資料」。
- [x] Dynamic Type 下保留重要百分比。

- Depends on：T-405、T-503
- 完成條件：VoiceOver 實機走查與 Dynamic Type font size 測試。

## Milestone 6：驗證與交付

### T-601 完成單元測試矩陣

- [x] Codable 與日期。
- [x] schema validation。
- [x] endpoint validation。
- [x] API client 錯誤分類。
- [x] cache 讀寫與損壞恢復。
- [x] Repository fallback。
- [x] freshness 邊界。
- [x] display mapping。
- [x] timeline provider。

- Depends on：T-101...T-505
- 完成條件：所有核心邏輯測試通過，無依賴真實私人 endpoint 的 automated test。

### T-602 完成 Widget 視覺矩陣

- [x] 正常資料。
- [x] 部分 window 缺值。
- [x] Provider 缺失。
- [x] delayed。
- [x] stale。
- [x] unavailable。
- [x] Light、Dark、Clear、Tinted。
- [x] Reduce Transparency、Increase Contrast。

- Depends on：T-504、T-505
- 完成條件：每個情境有可重現 preview 或實機紀錄；沒有截斷、低對比或只靠顏色的狀態。

### T-603 完成本機網路與 TLS 實機驗證

- [x] 首次本機網路權限。
- [x] 私人 CA 未信任時的錯誤。
- [x] 私人 CA 已信任時的成功請求。
- [x] hostname／SAN 不符時仍被拒願。
- [x] Wi-Fi、行動網路、飛航模式。
- [x] 離開 LAN 時的快取 fallback。

- Depends on：T-404、T-502
- 完成條件：不降低 TLS 驗證即可在目標環境成功；失敗情境符合規格且不洩漏 endpoint。

### T-604 驗證 Widget 真實更新行為

- [x] 在未連接 Xcode debugger 時安裝測試。
- [x] 觀察 timeline request 可能延後的情況。
- [x] 確認延後期間 stale UI 正確。
- [x] 確認 App 手動更新後 Widget reload。
- [x] 確認不對使用者宣稱 30 分鐘更新。

- Depends on：T-401、T-502
- 完成條件：至少完成一次實機長時間觀察，且快取／stale 策略可涵蓋系統延後更新。

### T-605 執行規格驗收案例

- [x] AC-001 至 AC-012 全部驗證。
- [x] 記錄發現的規格差異。
- [x] 修正程式或先更新規格並留下決策原因。

- Depends on：T-601、T-602、T-603、T-604
- 完成條件：所有 AC 通過，沒有未分類的第一版阻斷問題。

### T-606 安全與發布前檢查

- [x] 搜尋實際 endpoint、IP、DNS、token、Cookie、憑證與私鑰。
- [x] 確認 fixtures 與 screenshots 已匿名化。
- [x] 確認 ATS 與 URLSession 沒有跳過 TLS 驗證。
- [x] 確認 entitlements 只有必要權限。
- [x] 確認版本號、signing 與分發設定。

- Depends on：T-605
- 完成條件：repository 不含秘密或私有網路資訊，archive／安裝流程符合選定分發方式。

## Definition of Done

第一版只有在以下條件全部成立時才算完成：

- [x] 規格 `OPEN-*` 項目全數關閉。
- [x] App 與 Widget 可在實機安裝與啟動。
- [x] 三個 Provider 與兩個 quota windows 正確顯示。
- [x] null／missing 不被誤顯示為 0%。
- [x] App Group 設定與快取跨 process 正常。
- [x] 遠端失敗能安全 fallback，stale 狀態正確。
- [x] Clear 模式由系統呈現 Liquid Glass，其他外觀仍可讀。
- [x] VoiceOver、Dynamic Type 與基本對比檢查通過。
- [x] AC-001...AC-012 全數通過。
- [x] 自動測試通過且沒有依賴私人服務。
- [x] Repository 不含 secrets、私人 URL 或 TLS bypass。
