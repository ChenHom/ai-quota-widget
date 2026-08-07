# AIQuota 自動重新部署（避免免費簽章 7 天過期）

## 問題背景

這個 App 用 Xcode 直接 Run 到實體 iPhone 安裝，簽章團隊是免費個人 Apple ID
（Personal Team），iOS 只信任這種簽章 **7 天**。過期後 App 與 widget 會一起失效，
點擊 widget 會跳出「「AIQuota」無法再使用」。

`redeploy.sh` 在 iPhone 接上 USB 時被觸發，若距離上次成功部署超過 5 天，就重新
build + 安裝一次，藉此重置這 7 天信任窗。只認 wired（USB 接電腦）——WiFi／VPN
情境不處理，因為使用者接電腦時人就在現場，不需要額外的遠端觸發機制。

## 一次性設定

### 1. 編出 wrapper app

Image Capture 的「裝置連接時自動開啟」功能只能指定一個 App，不能直接指定 shell
script，所以用 `osacompile`（macOS 內建）編一個極簡的 wrapper：

```bash
osacompile -o ~/Applications/"AIQuota Redeploy.app" \
  -e 'do shell script "/Users/hom/code/ai/ai-quota-widget/scripts/redeploy.sh"'
```

### 2. 設定 Image Capture 的裝置 hook

1. 用 USB 線把 iPhone 接上這台 Mac。
2. 打開 **Image Capture.app**（`/Applications/Image Capture.app`）。
3. 在左側裝置列表點選這支 iPhone。
4. 視窗左下角「Connecting this iPhone opens:」下拉選單，選擇剛剛編出來的
   `AIQuota Redeploy.app`（選單裡選「Other…」瀏覽到 `~/Applications/`）。

設定完成後，之後每次這支 iPhone 接上 USB，系統就會自動啟動這個 wrapper app，
執行 `redeploy.sh`。

## 手動測試

- 直接雙擊 `~/Applications/AIQuota Redeploy.app`，或者
- 拔掉再插上一次 iPhone 的 USB 線。

跑完後檢查：

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
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration
  ```
  如果之後這個自動化開始莫名其妙失敗，先打開 Xcode 檢查 Accounts 頁面的登入狀態。
- **`do shell script` 的執行環境 PATH 比較精簡**。`xcodebuild`/`xcrun` 通常本來就
  在 `/usr/bin` 這種預設路徑下，理論上不用額外處理；但第一次透過 Image Capture
  hook 實際觸發測試時要確認一次，log 裡如果出現 `command not found`，才需要在
  `redeploy.sh` 開頭加 `export PATH=...`。

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
