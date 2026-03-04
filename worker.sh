#!/bin/bash
DOMAIN="$1"
GITHUB_RAW="https://raw.githubusercontent.com/ufavision/remove3page-add-fast-redirect-muplugin/main"
LOG_DIR="/root/redirect-logs"
LOG_FILE="$LOG_DIR/run-$(date '+%Y%m%d').log"
ALREADY_FILE="$LOG_DIR/already-has-plugin.log"
NO_PAGES_FILE="$LOG_DIR/no-pages-found.log"

mkdir -p "$LOG_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $DOMAIN | $1" | tee -a "$LOG_FILE"; }

# ดึง path จาก /etc/userdatadomains
LINE=$(grep "^$DOMAIN:" /etc/userdatadomains | head -1)
WP_PATH=$(echo "$LINE" | awk -F'==' '{print $5}')

if [ -z "$WP_PATH" ]; then
  log "⏭️ หา path ไม่เจอ - ข้าม"
  exit 0
fi

if [ ! -f "$WP_PATH/wp-config.php" ]; then
  log "⏭️ ไม่ใช่ WordPress - ข้าม ($WP_PATH)"
  exit 0
fi

# เช็ค fast-redirect.php มีอยู่แล้วไหม
MU_DIR="$WP_PATH/wp-content/mu-plugins"
if [ -f "$MU_DIR/fast-redirect.php" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $DOMAIN | $WP_PATH" >> "$ALREADY_FILE"
  log "⚠️ มีไฟล์อยู่แล้ว → เขียนทับ"
fi

# ลบ 3 Pages
NO_PAGES=()
for SLUG in "login-2" "register-2" "contact-us-2"; do
  PAGE_ID=$(wp post list --post_type=page --name="$SLUG" --field=ID --path="$WP_PATH" --allow-root 2>/dev/null)
  if [ -n "$PAGE_ID" ]; then
    wp post delete "$PAGE_ID" --force --path="$WP_PATH" --allow-root 2>/dev/null
    log "🗑️ ลบแล้ว: /$SLUG (ID: $PAGE_ID)"
  else
    NO_PAGES+=("/$SLUG")
  fi
done

# Log หน้าที่ไม่พบ
if [ ${#NO_PAGES[@]} -gt 0 ]; then
  MISSING=$(IFS=','; echo "${NO_PAGES[*]}")
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $DOMAIN | ไม่พบ: $MISSING" >> "$NO_PAGES_FILE"
  log "⚠️ ไม่พบหน้า: $MISSING"
fi

# วาง fast-redirect.php
mkdir -p "$MU_DIR"
curl -s "$GITHUB_RAW/fast-redirect.php" -o "$MU_DIR/fast-redirect.php"

if [ -f "$MU_DIR/fast-redirect.php" ]; then
  log "✅ สำเร็จ: $WP_PATH"
else
  log "❌ ไม่สำเร็จ: $WP_PATH"
fi
