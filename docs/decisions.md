# AIQuota 決策與修正記錄

最後更新：2026-09-17
相關文件：[產品規格](specification.md) · [實作規劃](implementation-plan.md) · [工作清單](tasks.md) · [部署自動化](../scripts/README.md)

本文件記錄開發過程中的問題修正與技術決策，每筆包含背景、原因分析、處理方式與驗證結果。

## 2026-09-17 清理：移除 `ProgressRingView`

Dashboard 改用橫向進度列後，`Shared/Presentation/ProgressRingView.swift` 就沒有任何呼叫端了 — 它原本只服務雙圓環版面。

一併從 `AIQuota.xcodeproj/project.pbxproj` 移除 8 行（3 個 target 的 `PBXBuildFile`、1 個 `PBXFileReference`、1 個 `PBXGroup` 子項、3 個 `PBXSourcesBuildPhase` 項目）。`project.yml` 是以資料夾（`- path: Shared`）納入來源，所以重跑 `xcodegen` 也會得到同樣結果；直接改 pbxproj 是為了不強迫每個人在這個 commit 之後先跑一次 xcodegen 才能建置。

移除前已確認四個相關 UUID 只出現在這 8 行裡，沒有其他地方參照。

## 2026-09-17 修正：Widget 補上重置券 `+N` 徽章

**現象**：macOS 面板與 App Dashboard 都會在 Provider 名稱旁顯示重置券的 `+N` 徽章，只有 Widget 沒有 — `MediumQuotaWidgetView` 從來沒有引用過 `resetCredits`。這不是回歸，是 2026-08-24 加徽章時就只做了 App 端。

**處理方式**：

- `providerRow` 的名稱欄改成 `HStack`，名稱後面接徽章，欄寬 52pt → 66pt。
- **每一列都留同樣的欄寬**，即使該 Provider 沒有券。不留的話三列的進度條會對不齊，比省下的 14pt 更礙眼。代價是進度條從約 59pt 縮到約 52pt。
- Widget 不能開 popover，徽章只顯示張數；到期時間仍然要進 App 才看得到。
- 徽章加 `.widgetAccentable()`，與進度條同一個 accent 群組，Tinted 模式下才不會被壓成次要色。
- `voiceOverLabel` 補上「重置券 N 張」：Widget 的徽章不是可觸達的控制項，張數只能靠列的 label 讀出來。

**順帶修正 MockData**：重置券原本掛在 `claude` 上，但 collector 的 schema v2 文件寫明只有 `codex` 會有值。改掛到 `codex`，預覽才符合真實資料 — 這同時也避開「最長的名稱 + 徽章」這個最擠的組合（`Claude` 46pt + 徽章 18pt 會超出 66pt 欄寬而觸發 `minimumScaleFactor`）。

**驗證**：未經編譯或測試執行。66pt 欄寬是依 13pt SF Pro Rounded 的字寬估算，需在模擬器確認 XXL／AX1 字級下不會溢出 — 這是既有 `decisions.md` 記錄過的那套 CLI 渲染驗證該跑的範圍。

## 2026-09-17 決策：Dashboard 多帳號改用疊牌按壓切換，與 macOS 端一致

**背景**：前一則決策把多帳號攤平成一個帳號一張卡片。實際比對後決定回到 macOS 端的疊牌：卡片疊在同一個位置，按下去整落沉到同一個位置，放開彈回時已經換成下一個帳號 — 交換就藏在收斂的那一刻。攤平的版本被否決。

**處理方式**：

- 新增 `ProviderStackDisplayState`，`ordered(from:)`／`account(after:)`／`index(of:)` 與 macOS 端的 `ProviderStack` 同一套邏輯：一律以 `account` 比對而非索引，因為伺服器每次快照都可能重排陣列。
- `QuotaDisplayState.providerStacks` 把攤平的 `providers` 依 `providerID` 分組，維持固定的 provider 順序。缺席的 provider 是只有一張佔位卡的單張牌。
- 動畫參數沿用 macOS 端的數值：`peek` 9pt、`shrink` 0.045、`maxVisibleDepth` 2、`pressDuration` 0.13s、`pressLevel` 0.5，彈回是 `.spring(response: 0.40, dampingFraction: 0.60)`。放開得太快時補足剩餘的沉下時間，否則兩張卡還沒收斂到同一個位置就交換，會被看見。
- 帳號標籤規則改回 macOS：只有非預設帳號掛標籤，`main` 沿用 provider 原名。疊牌一次只看得到一張卡，哪一張是 main 由指示點與底色交代。
- 加上 `AccountDots` 指示點。沿用 macOS 的結論：4pt 小圓點只靠明暗差看不出來，改用「作用中拉長成 10pt 膠囊」的形狀差。

**兩個 macOS 沒有、iOS 才有的問題**：

1. **不能把整張卡包成 `Button`**。`Button` 的 `isPressed` 在捲動把手勢帶走時同樣會轉 false，分不出「放開」與「取消」 — 照 macOS 的寫法，使用者每次捲過多帳號卡片都會誤換帳號。改用 `DragGesture(minimumDistance: 0)` 驅動沉下／彈回的動畫，另外用 `onTapGesture` 判斷這次算不算點擊：捲動不會產生 tap，帳號就不會被換掉。
2. **巢狀 `Button` 在 iOS 收不到點擊**。卡片裡的重置券徽章本身是 `Button`，包在外層 `Button` 的 label 裡會失效。用手勢而非 `Button` 同時解掉這一點。副作用是點徽章時外層的 `DragGesture` 仍會觸發一次沉下／彈回的小動畫（但不會換帳號），可接受。

另外：收尾一律排到下一輪 runloop 之後才做。`onTapGesture` 與 `DragGesture` 的 `onEnded` 在同一輪事件裡觸發、順序不保證，延後才能確定讀得到「這次是不是點擊」。疊在後面的卡片加 `allowsHitTesting(false)`，否則它們的徽章會搶走最前面那張的觸控。

**驗證**：本次在無 Swift 工具鏈的環境完成，**未經編譯或測試執行**。上面兩個 iOS 差異是靜態推理的結果，不是實測 — 手勢行為必須在實機或模擬器上確認，特別是「捲動經過多帳號卡片不會換帳號」與「點重置券徽章會開 popover」這兩條。測試只涵蓋得到純資料的部分：疊牌分組、循環排列、以 `account` 比對、單張牌沒有下一個帳號。

## 2026-09-17 決策：App Dashboard 版面對齊 macOS 端（多帳號呈現已由上一則取代）

**背景**：macOS 端（[ai-quota](https://github.com/ChenHom/ai-quota)）的 `QuotaPanel` 已改成「名稱列 + 5h／7d 兩條橫向進度列」的緊湊卡片，並支援多帳號。iPhone 端的 Dashboard 還停在雙圓環版面，兩邊看起來像兩個產品；schema v2 帶進來的第二個 claude 帳號在 iPhone 上也完全看不到。

**處理方式**：

- 卡片結構照搬 macOS 的 `ProviderCard`：名稱（headline）· 帳號標籤 · `+N` 重置券徽章 · Spacer · 最後成功時間 · 狀態膠囊，下面接 `5h`／`7d` 兩條 `UsageRow`。欄寬也沿用同一組數字（標籤 24pt、百分比 38pt、重置時間 116pt）。
- 新增標頭卡片顯示「AI USAGE ／ 最後同步：HH:mm」。這個資訊 iPhone 端原本完全沒顯示（`lastSyncText` 存在但沒有人用）。macOS 的重新整理按鈕在 iOS 由既有的下拉重新整理取代，只在載入時顯示轉圈。
- 狀態文案對齊 macOS：只分「正常／資料延遲／暫無資料」。原本 iPhone 端會把 collector 的原始 status 值（例如 `rate_limited`）直接顯示給使用者，`ProviderStatus` 改為 `.ok`／`.delayed(原始值)`／`.noData`，原始值保留在關聯值裡供診斷。
- **進度列刻意不照搬 macOS 的白色**。macOS 用白色是為了讓玻璃島在任意桌布上都可讀；iOS 卡片是實心底色，白色進度列會看不見。這裡沿用既有的 `ProgressBarView` 與語意色階，順帶讓 App 與 Widget 的色階一致（此前 App 用圓環、Widget 用色條）。
- ~~多帳號改成一個帳號一張卡片，而不是 macOS 的疊牌按壓切換。~~（已由 2026-09-17 的疊牌決策取代）原本的理由：macOS 疊牌是因為面板固定維持三張卡片、沒有空間往下長；Dashboard 是 ScrollView，沒有這個限制，攤平可讀性更好，也避開按壓手勢與捲動的衝突。非預設帳號的卡片用與 macOS 相同的三組色相（紫／青／粉）上底色並加帳號標籤；因為每個帳號都看得到，macOS 用來指示「現在看第幾張」的圓點就不需要了。
- `ProviderDisplayState.id` 改為 `provider/account` 複合鍵，並新增 `providerID`。`DashboardView` 與 `MediumQuotaWidgetView` 都用 `ForEach` 吃 `Identifiable`，兩列共用同一個 id 不會報錯，只會安靜地畫錯。

**Widget 維持不變**：`QuotaDisplayState` 新增 `defaultAccountProviders`，`MediumQuotaWidgetView` 改用它，維持固定三列。`systemMedium` 的垂直空間放不下第四列（預設字級勉強、XXL／AX1 幾乎確定溢出），Widget 的多帳號版面尚未定案，不讓它跟著 Dashboard 一起變。

**驗證**：本次在無 Swift 工具鏈的環境完成，**未經編譯或測試執行**。已完成的檢查：括號平衡掃描、全專案 grep 確認 `ProviderStatus`／`ProviderDisplayState` 的呼叫端都已更新。測試已補上一列一帳號、單帳號不顯示標籤、缺席 Provider 佔位、以及 `defaultAccountProviders` 仍為三列等案例。需在 Xcode 跑過 `xcodebuild test` 並實機看過版面才算驗證完成。

**後續**：`Shared/Presentation/ProgressRingView.swift` 在這次改動後沒有任何呼叫端，已於同一分支移除（見下方 2026-09-17 的清理記錄）。

## 2026-09-17 決策：跟進 collector schema v2，資料層先完整支援多帳號、顯示層暫時只取 `main`

**背景**：collector 自 2026-09-16 10:51 (+08:00) 起只輸出 schema v2（見 [public-schema-v2.md](https://github.com/ChenHom/ai-quota/blob/main/public-schema-v2.md)），v1 不再提供。v2 把 `providers.<key>` 從單一物件改成「一帳號一元素」的陣列，元素新增 `account`，`lastSuccessAt` 改為可為 null，另外多了 `confidence`／`source`／`usedPercent`。目前 `claude` 有 `main`、`work` 兩個帳號。

**原因分析**：這不是「跟進新欄位」而是既有版本已經壞掉。widget 端有三個獨立的破口，任一個都會讓 `fetchQuota` 拋錯、退回舊快取：

1. `QuotaResponse.providers` 宣告為 `[String: ProviderQuota]`，遇到陣列是 `typeMismatch`。
2. `ProviderQuota.lastSuccessAt` 是非 optional 的 `Date`，遇到 null 是 `valueNotFound`。
3. `QuotaAPIClient.supportedSchemaVersions` 是 `[1]`，v2 一律拒絕。

而且 `fetchQuota` 原本先解碼再驗版本，所以實際浮出的錯誤是第 1 項的「資料解析失敗」，把「資料格式版本不相容，請更新 App」這個真正有用的訊息蓋掉了。

**處理方式**：

- `providers` 改為 `[String: [ProviderQuota]]`。刻意不採用 macOS 端的固定三鍵結構：`agy` 本來就可能整個缺席，字典能自然承接，未來多一個 provider key 也只會被忽略而不是讓整份快照解碼失敗。
- `ProviderQuota` 新增 `account: String`（記憶體建構時預設 `main`，解碼時仍為必要欄位），`lastSuccessAt` 改為 `Date?`。
- `supportedSchemaVersions` 改為 `[2]`，並把版本檢查移到完整解碼之前：先用只含 `schemaVersion` 的輕量 `SchemaProbe` 解一次。跨版本連 `providers` 形狀都會變，順序反過來就會再次發生「版本問題被誤報成解析問題」。
- 新增 `QuotaResponse.accounts(of:)` 與 `primaryAccount(of:)`。後者先比對 `account == "main"`、找不到才退回第一個元素 — schema 文件明確要求以 `account` 比對而非依賴索引，因為伺服器會重排陣列。
- `confidence`／`source`／`usedPercent`／`applicableAvailableCount` 維持不解碼。Decodable 會忽略未宣告的 key，沿用 2026-08-24 對 `applicableAvailableCount` 的既有結論。
- **顯示層暫不改動**：`QuotaDisplayState.map` 改成取 `primaryAccount(of:)`，維持固定三列的既有外觀。多帳號版面（Widget 要擠進 `systemMedium`、改用 `systemLarge`、還是只在 App 端全顯示）尚未定案，先不讓資料層的修復被版面決策擋住。
- 舊快取在升版後解不開，`QuotaCache.load()` 會當作無快取回傳 `nil`（既有設計），第一次 refresh 即恢復，不會 crash。

**待辦**：多帳號版面定案後，`ProviderDisplayState.id` 必須從 `"claude"` 改成 `"claude/work"` 這類複合鍵。`DashboardView` 與 `MediumQuotaWidgetView` 兩處都用 `ForEach` 吃 `Identifiable`，兩列同 id 不會報錯，只會安靜地畫錯。

**驗證**：本次在無 Swift 工具鏈的環境完成，**未經編譯或測試執行**。已完成的檢查：5 份 fixture 的 JSON 語法驗證、全專案 grep 確認無殘留的 v1 形狀存取。測試已同步改寫並新增多帳號解碼、`account` 比對、null `lastSuccessAt`、未知欄位忽略、v1 形狀必須拒絕、版本檢查早於解碼（以 stub `URLProtocol` 實測 `QuotaAPIClient`）等案例，需在 Xcode 實機跑過 `xcodebuild test` 才算驗證完成。

## 2026-08-24 決策：`resetCredits` 以徽章加點擊清單呈現，不逐筆攤開

**背景**：collector 的 quota.json 新增 `resetCredits`（`availableCount`／`applicableAvailableCount`／`credits[]`），代表重置券張數與各張券的授予、到期時間。macOS 端（[ai-quota](https://github.com/ChenHom/ai-quota/blob/main/docs/development-decisions.md) 第 8 節）已決定用「徽章 + 摘要清單」呈現，iPhone 端沿用同一個結論。

**原因分析**：Dashboard 的 Provider 卡片是固定結構（名稱列 + 5h/7d 雙環 + 更新時間），逐筆攤開每張券會讓卡片高度隨券數浮動，券數又是隨時會變的資料；而重置券屬於偶爾查看的邊緣資訊，不值得長期佔用卡片版面。

**處理方式**：

- `ProviderQuota` 新增 `resetCredits: ResetCredits?`（`init` 預設 `nil`，既有呼叫端不受影響）；`ResetCredit` 只解 `status`／`grantedAt`／`expiresAt`。
- `applicableAvailableCount` 不解碼：collector 端尚未定義它與 `availableCount` 的差異語意，先不顯示一個意涵不確定的數字（Decodable 會忽略未宣告的 key，JSON 有這個欄位也不會出錯）。
- `ProviderDisplayState` 新增 `resetCredits: ResetCreditsDisplayState?`；mapping 時 `availableCount == 0` 或欄位缺失一律映射成 `nil`，沒有重置券的 Provider 完全不受影響。
- UI 只在 Provider 名稱旁加一個 `+N` 膠囊徽章，點擊以 `.popover`（`presentationCompactAdaptation(.popover)`，iPhone 上維持氣泡而非 sheet）列出每張券的到期時間。
- 到期時間固定以 `Asia/Taipei` 換算顯示，不隨裝置時區改變，與 collector 端口徑一致；卡片其他時間（更新時間、5h／7d 重置時間）維持裝置時區，這次不一併改動。
- Widget 不加徽章：medium widget 每列已經是「名稱 + 5h + 7d 進度條」，空間吃緊，且 widget 不能點開清單，只顯示張數等於資訊不完整。

**驗證**：`testResetCreditsDecoding` 驗證含 `applicableAvailableCount` 與 `expiresAt: null` 的 JSON 能正確解碼；`testResetCreditsMapping` 驗證徽章文字、Asia/Taipei 到期時間格式，以及 0 張券／缺欄位映射為 `nil`。

**取捨**：使用者要多一次點擊才看得到完整到期清單。若之後重置券變成常態關注重點，再考慮在 5h／7d 下面加第三行，而不是藏在點擊互動裡。

## 2026-08-20 決策：放棄 Image Capture 自動觸發，改為手動雙擊重新部署

**現象**：2026-08-07 設定好的「iPhone 接上 USB 就自動重新部署」流程，13 天內完全沒有再自動跑過——`redeploy.log` 裡只有設定當晚（23:10-23:11）的紀錄，之後即使多次接上 USB 也沒有任何新的 log。

**原因分析**：診斷發現整個自動觸發機制在這台 Mac（macOS 26.5.2）上根本不會生效：`~/Library/Preferences/com.apple.imagecapture.plist` 裡只有 `loggingLevel`，從來沒有寫入任何裝置 hook 設定；這個功能傳統上的設定檔 `com.apple.digihub.plist` 根本不存在；`log show` 查詢最近 3 天完全找不到 `imagecaptureagent`／`digihub` 任何行程活動；`launchctl list` 與所有 LaunchAgent/LaunchDaemon plist 裡也沒有對應的常駐服務註冊。判斷 Image Capture 這個「裝置連接時自動開啟指定 App」功能在此系統版本上已經失效或被移除，8/7 當晚 GUI 裡設定的下拉選單從未真正被系統持久化。

**決策**：不追加更複雜的觸發機制（例如自行寫 IOKit USB attach 事件常駐程式），改為最簡單的路：`scripts/redeploy.sh` 與 `~/Applications/AIQuota Redeploy.app` 都維持不變，只是觸發方式改成手機接上 USB 後手動雙擊一下 wrapper app。腳本本身已經有 5 天門檻 + 手機不在時安全跳過的邏輯，重複手動執行沒有副作用。移除 `scripts/README.md` 裡的 Image Capture 設定步驟。

**驗證**：`com.apple.imagecapture.plist`、`com.apple.digihub.plist`、`log show --predicate 'process contains "ImageCapture" or process contains "digihub"' --last 3d`、`launchctl list` 四項檢查交叉確認同一個結論——系統層級找不到任何這個 hook 曾經觸發或被登記的痕跡。

**補充**：純手動觸發最大的風險是忘記，所以另外加了 `scripts/remind.sh` + `launchd` LaunchAgent（`com.hom.aiquota-redeploy-reminder`，機器專屬設定，不進 repo），每天 09:00 檢查一次距離上次成功部署天數，≥ 5 天就發系統通知提醒手動接上手機雙擊 wrapper app；純時間檢查，不碰裝置狀態，跟被判定失效的 Image Capture 機制無關。已用假造的舊 `last-success` 時間戳測試過通知邏輯正常觸發。

## 2026-08-07 決策：新增 iPhone 自動重新部署腳本，避免免費簽章 7 天過期

**現象**：已安裝在 iPhone 上的 AIQuota App 與 Widget，會在一段時間後整個無法使用——點擊 widget 跳出系統彈窗「「AIQuota」無法再使用」，App 圖示本身也無法開啟。

**原因分析**：這個 App 目前用 Xcode 直接 Run 到實體 iPhone 安裝，`DEVELOPMENT_TEAM = 64A8UWB8MW` 對應的是免費個人 Apple ID（Personal Team，`isFreeProvisioningTeam = 1`）。這類簽章 iOS 只信任**7 天**，過期後整個 App（含內嵌的 widget extension）會被系統撤銷執行權限。診斷過程中先逐一排除了 TLS 憑證信任、iOS widget 背景刷新預算被節流、App Group 快取失效等可能性——這些因素在 App 還沒過期的那幾天內確實可能造成暫時性的資料延遲，但「整個 App 無法開啟」這個規律性的失效，根因是簽章信任期限，不是資料層或網路層的問題。

**決策**：不改用付費 Apple Developer Program（$99/年，簽章效期可延長到 1 年），而是新增 `scripts/redeploy.sh` 自動化腳本：iPhone 接上 USB 時（透過 macOS 內建 Image Capture 的裝置連接 hook 觸發，設定步驟見 [`scripts/README.md`](../scripts/README.md)），若距離上次成功部署超過 5 天，就重新 build + 安裝一次，持續重置這 7 天信任窗。範圍刻意只處理 wired（USB 接電腦）情境，不處理 WiFi/VPN 遠端觸發——使用者接電腦時人在現場，安裝失敗與否會自己察覺，不需要額外通知機制；只有 build 本身失敗（簽章壞掉、專案設定跑掉等結構性問題）才會用系統通知提醒，因為那代表自動化本身壞了，跟手機在不在現場無關。

**驗證**：實測跑過完整流程——手動執行 `xcodebuild ... -allowProvisioningUpdates ...` 確認無互動提示、乾淨成功；執行 `redeploy.sh` 完成一次真實的 build + `devicectl install`，iPhone 上的 App 恢復正常；立即再執行一次確認 due-check 正確略過（避免每次充電都重新 build）；透過 Image Capture hook 觸發的 wrapper app 亦手動雙擊測試過會正確呼叫腳本。

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
