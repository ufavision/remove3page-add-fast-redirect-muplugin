#!/bin/bash
GITHUB_RAW="https://raw.githubusercontent.com/ufavision/remove3page-add-fast-redirect-muplugin/main"
LOG_DIR="/root/redirect-logs"
mkdir -p "$LOG_DIR"

# ===== เช็ค Spec ตั้งค่า Parallel =====
CPU=$(nproc)
RAM_GB=$(free -g | awk '/Mem:/{print $2}')

if [ "$CPU" -ge 16 ] && [ "$RAM_GB" -ge 32 ]; then
  JOBS=8
elif [ "$CPU" -ge 8 ] && [ "$RAM_GB" -ge 16 ]; then
  JOBS=4
elif [ "$CPU" -ge 4 ] && [ "$RAM_GB" -ge 8 ]; then
  JOBS=2
else
  JOBS=1
fi

echo "======================================"
echo "🖥️  CPU: $CPU cores | RAM: ${RAM_GB}GB"
echo "⚡ Parallel Jobs: $JOBS"
echo "======================================"

# ===== Function ทำงานต่อ 1 domain =====
process_domain() {
  local DOMAIN="$1"
  local GITHUB_RAW="$2"
  local LOG_DIR="$3"
  local LOG_FILE="$LOG_DIR/run-$(date '+%Y%m%d').log"
  local ALREADY_FILE="$LOG_DIR/already-has-plugin.log"
  local NO_PAGES_FILE="$LOG_DIR/no-pages-found.log"

  log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $DOMAIN | $1" | tee -a "$LOG_FILE"; }

  # ดึง path และ username
  LINE=$(grep "^$DOMAIN:" /etc/userdatadomains | head -1)
  USERNAME=$(echo "$LINE" | awk -F'==' '{print $1}' | awk -F': ' '{print $2}' | tr -d ' ')
  WP_PATH=$(echo "$LINE" | awk -F'==' '{print $5}')

  if [ -z "$WP_PATH" ]; then
    log "⏭️ หา path ไม่เจอ - ข้าม"
    return
  fi

  if [ ! -f "$WP_PATH/wp-config.php" ]; then
    log "⏭️ ไม่ใช่ WordPress - ข้าม ($WP_PATH)"
    return
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

  # แก้ permission ✅
  chown "$USERNAME":"$USERNAME" "$MU_DIR"
  chown "$USERNAME":"$USERNAME" "$MU_DIR/fast-redirect.php"
  chmod 755 "$MU_DIR"
  chmod 644 "$MU_DIR/fast-redirect.php"

  if [ -f "$MU_DIR/fast-redirect.php" ]; then
    log "✅ สำเร็จ: $WP_PATH"
  else
    log "❌ ไม่สำเร็จ: $WP_PATH"
  fi
}

export -f process_domain
export GITHUB_RAW LOG_DIR

# ===== ดึงทุก domain =====
DOMAINS=$(awk -F'==' '$3=="main" || $3=="addon" {print $1}' /etc/userdatadomains \
  | awk -F': ' '{print $1}' | sort -u)

TOTAL=$(echo "$DOMAINS" | wc -l)
echo "📋 พบ domain ทั้งหมด: $TOTAL"
echo "======================================"

# ===== รันแบบ Parallel =====
echo "$DOMAINS" | xargs -P "$JOBS" -I {} bash -c 'process_domain "$@"' _ {} "$GITHUB_RAW" "$LOG_DIR"

# ===== สรุปผล =====
echo ""
echo "======================================"
echo "📊 สรุปผล"
echo "======================================"
SUCCESS=$(grep -c "✅ สำเร็จ" "$LOG_DIR/run-$(date '+%Y%m%d').log" 2>/dev/null || echo 0)
FAILED=$(grep -c "❌ ไม่สำเร็จ" "$LOG_DIR/run-$(date '+%Y%m%d').log" 2>/dev/null || echo 0)
SKIPPED=$(grep -c "⏭️" "$LOG_DIR/run-$(date '+%Y%m%d').log" 2>/dev/null || echo 0)
ALREADY=$(wc -l < "$LOG_DIR/already-has-plugin.log" 2>/dev/null || echo 0)
NO_PAGES=$(wc -l < "$LOG_DIR/no-pages-found.log" 2>/dev/null || echo 0)

echo "✅ สำเร็จ                    : $SUCCESS เว็บ"
echo "❌ ไม่สำเร็จ                  : $FAILED เว็บ"
echo "⏭️  ข้าม (ไม่ใช่ WP)          : $SKIPPED เว็บ"
echo "⚠️  มีไฟล์อยู่แล้ว (เขียนทับ)  : $ALREADY เว็บ"
echo "⚠️  ไม่พบหน้า login/register   : $NO_PAGES เว็บ"
echo ""
echo "📁 Log อยู่ที่: $LOG_DIR/"
echo "   - run-$(date '+%Y%m%d').log      ← log ทั้งหมด"
echo "   - already-has-plugin.log         ← เว็บที่มีไฟล์อยู่แล้ว"
echo "   - no-pages-found.log             ← เว็บที่ไม่มีหน้า"
exit 0
