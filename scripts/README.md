# AIQuota 手動重新部署（避免免費簽章 7 天過期）

## 問題背景

這個 App 用 Xcode 直接 Run 到實體 iPhone 安裝，簽章團隊是免費個人 Apple ID
（Personal Team），iOS 只信任這種簽章 **7 天**。過期後 App 與 widget 會一起失效，
點擊 widget 會跳出「「AIQuota」無法再使用」。

`redeploy.sh` 若距離上次成功部署超過 5 天，就重新 build + 安裝一次，藉此重置這
7 天信任窗；沒到門檻或手機沒接著都會安靜跳過，可以放心重複執行。

**原本設計是接上 USB 就透過 macOS Image Capture 的裝置 hook 自動觸發，但實測
發現這台 Mac（macOS 26.5.2）上這個機制根本不會觸發**——`com.apple.imagecapture.plist`
沒有寫入任何裝置 hook 設定、`com.apple.digihub.plist`（這功能的傳統設定檔）
不存在、`log show` 也查不到任何 `imagecaptureagent`/`digihub` 行程活動，
launchd 裡也沒有對應的常駐服務。連續 13 天多次接上 USB，自動化完全沒有再跑過
一次。判斷是這個系統版本已經拿掉/不支援這個 hook 了，所以放棄自動觸發，改成
**手動觸發**：接上手機時自己雙擊一下即可。

## 一次性設定

### 1. 編出可雙擊執行的 wrapper app

比每次打開 Terminal 方便：

```bash
osacompile -o ~/Applications/"AIQuota Redeploy.app" \
  -e 'do shell script "/Users/hom/code/ai/ai-quota-widget/scripts/redeploy.sh"'
```

### 2. 安裝每日提醒（避免忘記手動觸發）

手動觸發最大的風險是忘記。`scripts/remind.sh` 每天被 `launchd` 叫醒一次，距離
上次成功部署 ≥ 5 天時發系統通知；沒到門檻就安靜結束，純檢查、不做 build/安裝。

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.hom.aiquota-redeploy-reminder.plist
```

LaunchAgent plist（`~/Library/LaunchAgents/com.hom.aiquota-redeploy-reminder.plist`，
機器專屬設定，不進 repo）：每天 09:00 執行 `scripts/remind.sh`，log 在
`~/Library/Logs/AIQuota-Redeploy/remind.log`。

## 使用方式

手機接上 USB 後，雙擊 `~/Applications/AIQuota Redeploy.app`（或直接執行
`scripts/redeploy.sh`）。跑完後檢查：

```bash
cat ~/Library/Logs/AIQuota-Redeploy/redeploy.log
cat ~/Library/Application\ Support/AIQuota-Redeploy/last-success   # epoch 秒數
```

## 已知風險

- **`-allowProvisioningUpdates` 依賴 Xcode 目前登入的 Apple ID session**。這通常
  是靜默續期，但如果 Apple 哪天要求重新登入／2FA，背景執行的 `xcodebuild` 沒辦法
  回應互動提示，會失敗。上線前務必先在 Terminal 手動跑一次一模一樣的 build 指令，
  確認完全不跳互動視窗、乾淨結束：
  ```bash
  xcodebuild build -project AIQuota.xcodeproj -scheme AIQuota -configuration Debug \
    -destination "generic/platform=iOS" -derivedDataPath build/DerivedData \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    INFOPLIST_KEY_AIQuotaCommit="$(git rev-parse --short HEAD)" \
    MARKETING_VERSION="$(git rev-parse --short HEAD)"
  ```
  如果之後這個自動化開始莫名其妙失敗，先打開 Xcode 檢查 Accounts 頁面的登入狀態。
- **`do shell script` 的執行環境 PATH 比較精簡**。`xcodebuild`/`xcrun` 通常本來就
  在 `/usr/bin` 這種預設路徑下，理論上不用額外處理；但第一次雙擊 wrapper app
  觸發時要確認一次，log 裡如果出現 `command not found`，才需要在 `redeploy.sh`
  開頭加 `export PATH=...`。

## 建置識別（commit SHA）

App 標頭「最後同步」那一行的右側會顯示 build 當下的 commit SHA，用來分辨手機上跑的
到底是哪一版。後綴 `+` 表示 build 當下工作區還有未提交的改動。

build 時同時帶兩個設定，App 端（`AppConfiguration.buildLabel`）依序讀：

| 順序 | Info.plist key | 來源設定 | 備註 |
|---|---|---|---|
| 1 | `AIQuotaCommit` | `INFOPLIST_KEY_AIQuotaCommit` | `INFOPLIST_KEY_` 前綴官方只保證支援它已知的 key，自訂 key 可能被靜默忽略 |
| 2 | `CFBundleShortVersionString` | `MARKETING_VERSION` | 標準設定，一定會進 Info.plist |

之所以兩個都帶，是因為只用第 1 個實測過顯示 `dev`（值沒進 plist）。第 2 個是保險。
`MARKETING_VERSION` 不帶 `+` 後綴 — `CFBundleShortVersionString` 對特殊字元比較敏感。

**直接在 Xcode 按 Run 不會帶任何一個**，此時顯示 `project.yml` 裡的 `MARKETING_VERSION`
（目前是 `1.1`）。這是預期行為。

手動下指令時兩個都要帶：

```bash
INFOPLIST_KEY_AIQuotaCommit="$(git rev-parse --short HEAD)" \
MARKETING_VERSION="$(git rev-parse --short HEAD)"
```

要確認值真的有進去，檢查建置產物的 Info.plist：

```bash
plutil -p build/DerivedData/Build/Products/Debug-iphoneos/AIQuota.app/Info.plist \
  | grep -E "AIQuotaCommit|CFBundleShortVersionString"
```

## 狀態／log 位置

- `~/Library/Application Support/AIQuota-Redeploy/last-success` — 上次成功部署的
  epoch 秒數。
- `~/Library/Application Support/AIQuota-Redeploy/redeploy.lock` — 執行期間的鎖
  目錄，正常情況下執行完會自動清掉。
- `~/Library/Logs/AIQuota-Redeploy/redeploy.log` — 每次觸發的完整 log（含
  build/install 的原始輸出）。

## 換手機時

`redeploy.sh` 開頭的 `UDID` 是寫死的（目前是 `2A7AFE17-04B0-5243-A8B0-D3FD4D0BE8F3`，
Hom 的 iPhone）。如果之後換了 iPhone，記得更新這個值：`xcrun devicectl list devices`
可以查到新裝置的 Identifier。
