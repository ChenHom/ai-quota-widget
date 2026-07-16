# iOS 26 Liquid Glass 技術筆記

最後更新：2026-07-16
相關文件：[決策與修正記錄](decisions.md)

2026-07-16 為了「widget 背景改用原生玻璃材質」需求所做的調查整理。查證依據：Xcode 26.6 內附 iOS 26.5 SDK 的 swiftinterface 定義（本機驗證）與 Apple WidgetKit 文件。

## 1. Widget 的玻璃背景：系統套用，無 iOS API 可直接指定

- **iOS 上沒有任何 API 能在程式碼中把 home screen widget 背景設為 Liquid Glass。**
  WidgetKit 的 `widgetTexture(_:)`（`.glass` / `.paper`）在 iOS 26.5 SDK 中標記為
  `@available(visionOS 26.0)` + `@available(iOS, unavailable)` — **僅 visionOS（Vision Pro）可用**，iOS 編譯直接失敗。
- 原生 widget 的玻璃外觀來自**系統**：使用者長按主畫面 → 編輯 → 自訂 → 外觀選「**透明（Clear）**」或「有色（Tinted）」時，系統會自動移除 widget 以 `containerBackground(for: .widget)` 指定的背景，換上與 Apple 原生 widget 完全相同的 Liquid Glass。
- App 端要滿足的條件只有兩個：
  1. 背景必須「可移除」— 這是預設行為；**不要**呼叫 `containerBackgroundRemovable(false)`（呼叫了還會被排除在 iPad 鎖定畫面與 StandBy 之外）。
  2. 內容要能適應 accented 渲染模式 — 以 `@Environment(\.widgetRenderingMode)` 偵測，重點元素標記 `.widgetAccentable()`；未標記的內容在 accented/清晰模式下會被系統自動去飽和處理。
- **自行移除背景不等於玻璃**：`Color.clear` 或拿掉 `containerBackground(for: .widget)` 在預設模式下不會產生玻璃，只會失去面板；iOS 17+ 完全不寫該 modifier 會顯示系統錯誤佔位訊息。
- Widget 是離線渲染後由 SpringBoard 合成，**無法取樣或模糊桌布**——`glassEffect()` 在 widget 內做不出真玻璃，材質（如 `.ultraThinMaterial`）也不會透出桌布。市面上「透明小工具」App 都是用桌布截圖假造的。

## 2. App 內 UI 的 Liquid Glass API（iOS 26+，一般 App 介面用，非 widget）

- `.glassEffect(_:in:)`：對 view 套用玻璃，預設 `.regular` 玻璃與 capsule 形狀。
- `GlassEffectContainer(spacing:)`：把多個 `glassEffect` 子 view 的玻璃層合併成連續表面，控制相近玻璃形狀的融合（morphing）距離。
- 按鈕樣式：`.buttonStyle(.glass)`、`.buttonStyle(.glassProminent)`（SDK 已驗證存在）。
- 常見錯誤（社群整理）：
  - 不要在 `glassEffect` 之上再疊 `.blur`、`.opacity`、`.background`。
  - 不要在玻璃 view 背後放實色底（如 `Color.white` / `Color.black`），會蓋掉折射效果。
  - 不要對 `glassEffect` view 使用 `.clipShape`；要形狀請用 `glassEffect(_:in:)` 的 shape 參數。
  - `GlassEffectContainer` 不可巢狀。

## 3. 本專案的結論

見[決策與修正記錄](decisions.md)：維持 `.containerBackground(.ultraThinMaterial, for: .widget)` 不變，玻璃交由系統在透明/有色模式下自動套用；本專案已滿足全部條件。

## 參考來源

- [WidgetKit: Implementing Liquid Glass Design（Apple 官方文件鏡像）](https://github.com/artemnovichkov/xcode-27-system-prompts/blob/main/AdditionalDocumentation/WidgetKit-Implementing-Liquid-Glass-Design.md)
- [Designing custom UI with Liquid Glass on iOS 26 – Donny Wals](https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/)
- [Understanding GlassEffectContainer in iOS 26 – DEV Community](https://dev.to/arshtechpro/understanding-glasseffectcontainer-in-ios-26-2n8p)
- iOS 26.5 SDK `WidgetKit.swiftmodule` / `SwiftUI.swiftmodule` swiftinterface（本機驗證 `widgetTexture` 與 glass 相關 API 的可用性標註）
