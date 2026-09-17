#!/bin/bash
# 免費個人 Apple ID 簽章的 App 在 iPhone 上只被信任 7 天，過期後 AIQuota App／Widget 會整個
# 無法啟動（點擊跳出「無法再使用」）。手機接上 USB 後手動雙擊 wrapper app 觸發（見
# scripts/README.md），距離上次成功部署超過 5 天就重新 build + 安裝一次，把 7 天信任窗重置。
set -uo pipefail

UDID="2A7AFE17-04B0-5243-A8B0-D3FD4D0BE8F3"
PROJECT_DIR="/Users/hom/code/ai/ai-quota-widget"
PROJECT="$PROJECT_DIR/AIQuota.xcodeproj"
SCHEME="AIQuota"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="$PROJECT_DIR/build/DerivedData"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos/AIQuota.app"

STATE_DIR="$HOME/Library/Application Support/AIQuota-Redeploy"
STATE_FILE="$STATE_DIR/last-success"
LOCK_DIR="$STATE_DIR/redeploy.lock"
LOG_DIR="$HOME/Library/Logs/AIQuota-Redeploy"
LOG_FILE="$LOG_DIR/redeploy.log"

REDEPLOY_THRESHOLD_DAYS=5

mkdir -p "$STATE_DIR" "$LOG_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

notify() {
    osascript -e "display notification \"$1\" with title \"AIQuota Redeploy\"" >/dev/null 2>&1
}

# ponytail: mkdir 是 atomic 的，靠它當簡易 lock；30 分鐘內視為別的實例還在跑，直接讓出。
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0) ))
    if [ "$lock_age" -lt 1800 ]; then
        log "已有其他 redeploy 實例在跑，略過"
        exit 0
    fi
    log "偵測到超過 30 分鐘的殘留 lock，視為上次當機，接手繼續"
    rmdir "$LOCK_DIR" 2>/dev/null
    mkdir "$LOCK_DIR" 2>/dev/null
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

last_success=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
age_days=$(( ($(date +%s) - last_success) / 86400 ))

if [ "$age_days" -lt "$REDEPLOY_THRESHOLD_DAYS" ]; then
    log "距離上次成功部署 ${age_days} 天，還沒到 ${REDEPLOY_THRESHOLD_DAYS} 天門檻，略過"
    exit 0
fi

log "距離上次成功部署 ${age_days} 天，開始重新 build + 安裝"

# 建置識別：寫進 Info.plist，App 標頭右上角會顯示，用來分辨手機上跑的是哪一版。
# 後綴 + 表示 build 當下工作區還有未提交的改動（與 macOS 端的口徑一致）。
#
# 兩個設定都帶：INFOPLIST_KEY_ 的自訂 key 不是每個 Xcode 版本都吃，
# MARKETING_VERSION 則是標準設定，一定會進 Info.plist。App 端優先讀前者。
# MARKETING_VERSION 不帶 + 後綴：CFBundleShortVersionString 對特殊字元比較敏感。
COMMIT=$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo dev)
COMMIT_PLAIN="$COMMIT"
if ! git -C "$PROJECT_DIR" diff --quiet HEAD 2>/dev/null; then
    COMMIT="${COMMIT}+"
fi
log "建置識別：${COMMIT}"

build_output=$(xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    INFOPLIST_KEY_AIQuotaCommit="$COMMIT" \
    MARKETING_VERSION="$COMMIT_PLAIN" 2>&1)
build_status=$?
echo "$build_output" >> "$LOG_FILE"

if [ "$build_status" -ne 0 ] || [ ! -d "$APP_PATH" ]; then
    log "Build 失敗（exit $build_status）"
    notify "Build 失敗，請打開 Xcode 檢查簽章／專案設定"
    exit 1
fi

install_output=$(xcrun devicectl device install app --device "$UDID" "$APP_PATH" 2>&1)
install_status=$?
echo "$install_output" >> "$LOG_FILE"

if [ "$install_status" -ne 0 ]; then
    log "安裝失敗（exit $install_status），不通知（wired 情境使用者應該就在電腦前）"
    exit 1
fi

date +%s > "$STATE_FILE"
log "安裝成功，已重置 7 天信任窗"
