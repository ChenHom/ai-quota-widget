# AIQuota 決策與修正記錄

最後更新：2026-07-16
相關文件：[產品規格](specification.md) · [實作規劃](implementation-plan.md) · [工作清單](tasks.md)

本文件記錄開發過程中的問題修正與技術決策，每筆包含背景、原因分析、處理方式與驗證結果。

## 2026-07-16 修正：Widget Provider 名稱「Claude」折成兩行

**現象**：Home Screen Widget 上 Provider 名稱「Claude」顯示為兩行。

**原因**：`MediumQuotaWidgetView.providerRow` 的名稱欄使用 `.font(.footnote)`（動態字體，會隨系統「文字大小」設定放大）但欄寬固定 50pt。系統字體調大後名稱塞不下即折行。先前嘗試加上 `.fixedSize(horizontal: true)` 不但無效，反而使 `.minimumScaleFactor` 失效，文字以理想寬度溢出欄位、蓋住旁邊的「5h」標籤。

**處理**（`AIQuotaWidgetExtension/MediumQuotaWidgetView.swift`）：

- 字體改為固定字級 `.system(size: 13, weight: .bold, design: .rounded)`，不受動態字體影響，與同列的「5h/7d」（8pt）、百分比（10pt）固定字級一致。
- 移除 `.fixedSize`，保留 `.lineLimit(1)` + `.minimumScaleFactor(0.6)`：名稱過長時縮小而非折行。
- 欄寬調整為 52pt。

**驗證**：以 CLI 渲染工具（swiftc 編譯實際原始碼 + `simctl spawn` 在 iOS 26.5 模擬器執行 `ImageRenderer` 輸出 PNG）測試「標準 329×155／窄版 291×141」×「預設／XXL／輔助功能 AX1 字級」共 5 種組合，全部維持單行且不溢出；`xcodebuild` 全專案編譯通過。

## 2026-07-16 評估：App Group CFPrefs 警告訊息為無害雜訊

**現象**：執行時 console 出現 `Couldn't read values in CFPrefsPlistSource ... Using kCFPreferencesAnyUser with a container is only allowed for System Containers, detaching from cfprefsd`。

**分析**：這是首次開啟 App Group 的 `UserDefaults(suiteName:)` 時，Apple framework 探測 AnyUser/ByHost 層級（App Group 本來就不允許）產生的已知雜訊，不影響實際讀寫。已驗證三項事實：

1. App 與 Widget Extension 兩個產物都正確嵌入 `group.com.hom.AIQuota` entitlement（模擬器 build 位於 `__TEXT,__entitlements` section，`codesign` 簽章顯示為空是正常現象）。
2. 模擬器上 App Group 容器成功解析到實際路徑（`simctl get_app_container ... groups`）。
3. App 啟動後群組容器內 `Library/Preferences` 正常建立。

另外 `Connection invalidated` 與 `exit code 9 (killed)` 亦屬正常：widget extension 在 timeline 渲染完成後本來就會被系統以 SIGKILL 回收；在 Xcode 按停止鈕同樣得到 exit code 9。

**決策**：不做任何程式碼修改。

## 2026-07-16 決策：Widget 玻璃背景交由系統處理，維持 containerBackground 現狀

**需求**：希望 widget 背景使用與原生相同的玻璃材質（Liquid Glass）。

**調查結果**（完整技術細節見 [Liquid Glass 技術筆記](liquid-glass-notes.md)）：

- iOS 沒有 API 可在程式碼中直接指定 widget 背景為 Liquid Glass。WidgetKit 的 `widgetTexture(.glass)` 在 iOS 26.5 SDK 介面定義中標記 `@available(visionOS 26.0)` + `@available(iOS, unavailable)`，僅 visionOS 可用。
- `glassEffect()` 在 widget 內做不出真玻璃：home screen widget 離線渲染後合成，無法取樣或模糊桌布。
- 原生玻璃外觀由系統套用：使用者將主畫面外觀切為「透明（Clear）」或「有色（Tinted）」時，系統自動移除 widget 指定的 containerBackground，換上與原生 widget 相同的 Liquid Glass。

**決策**：程式碼維持 `.containerBackground(.ultraThinMaterial, for: .widget)` 不變。套用系統玻璃的兩個條件本專案均已滿足：背景可移除（未呼叫 `containerBackgroundRemovable(false)`）、進度條已標記 `.widgetAccentable()`。不自行移除背景 — 換成 `Color.clear` 或拿掉 modifier 在預設模式下不會變玻璃，只會失去面板甚至觸發系統錯誤佔位。

## 開發環境備註：模擬器信任自簽憑證

Collector endpoint 走 HTTPS 自簽憑證時，模擬器信任方式：

```bash
xcrun simctl keychain booted add-root-cert /path/to/rootCA.pem
```

加入後重啟 App 即生效（設定 → 一般 → 關於本機 → 憑證信任設定可確認）。注意伺服器憑證必須含 SAN（含連線用的主機名稱或 IP）、有效期 ≤ 825 天、RSA ≥ 2048、SHA-256 以上；建議以 `mkcert` 產生。此作法符合規格「不停用 TLS 憑證或 hostname 驗證」的安全邊界。
