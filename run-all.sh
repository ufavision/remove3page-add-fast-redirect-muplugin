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

# โหลด worker.sh จาก GitHub
curl -s "$GITHUB_RAW/worker.sh" -o /tmp/worker.sh
chmod +x /tmp/worker.sh

# ✅ แก้ Bug: ดึงเฉพาะ main และ addon domain (ไม่เอา sub)
DOMAINS=$(awk -F'==' '$3=="main" || $3=="addon" {print $1}' /etc/userdatadomains \
  | awk -F': ' '{print $1}' \
  | sort -u)

TOTAL=$(echo "$DOMAINS" | wc -l)
echo "📋 พบ WordPress domain: $TOTAL"
echo "======================================"

# รันแบบ Parallel
echo "$DOMAINS" | xargs -P "$JOBS" -I {} bash /tmp/worker.sh {}

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
