#!/bin/bash
# 手動觸發 redeploy.sh 容易忘記，這支腳本每天被 launchd 叫醒一次，距離上次成功部署
# 超過門檻天數時用系統通知提醒（設定見 scripts/README.md）。不做 build/安裝，純提醒。
set -uo pipefail

STATE_FILE="$HOME/Library/Application Support/AIQuota-Redeploy/last-success"
REMIND_THRESHOLD_DAYS=5

last_success=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
age_days=$(( ($(date +%s) - last_success) / 86400 ))

if [ "$age_days" -ge "$REMIND_THRESHOLD_DAYS" ]; then
    osascript -e "display notification \"距離上次部署已 ${age_days} 天，接上 iPhone 後雙擊 AIQuota Redeploy.app\" with title \"AIQuota\"" >/dev/null 2>&1
fi
