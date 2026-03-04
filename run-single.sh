#!/bin/bash
GITHUB_RAW="https://raw.githubusercontent.com/ufavision/remove3page-add-fast-redirect-muplugin/main"
LOG_DIR="/root/redirect-logs"
mkdir -p "$LOG_DIR"

# ===== ดึงรายชื่อเว็บทั้งหมดที่เป็น WordPress =====
echo "======================================"
echo "🔍 กำลังค้นหาเว็บ WordPress ทั้งหมด..."
echo "======================================"

WP_DOMAINS=()
while IFS= read -r line; do
  DOMAIN=$(echo "$line" | awk -F': ' '{print $1}' | tr -d ' ')
  WP_PATH=$(echo "$line" | awk -F'==' '{print $5}')
  if [ -f "$WP_PATH/wp-config.php" ]; then
    WP_DOMAINS+=("$DOMAIN")
  fi
done < <(awk -F'==' '$3=="main" || $3=="addon"' /etc/userdatadomains)

TOTAL=${#WP_DOMAINS[@]}
if [ "$TOTAL" -eq 0 ]; then
  echo "❌ ไม่พบเว็บ WordPress เลย"
  exit 1
fi

# ===== สุ่มเว็บ =====
RANDOM_INDEX=$((RANDOM % TOTAL))
DOMAIN="${WP_DOMAINS[$RANDOM_INDEX]}"

echo "🎲 สุ่มได้เว็บ: $DOMAIN"
echo "📋 จากทั้งหมด: $TOTAL เว็บ"
echo "======================================"

# ===== ดึง path =====
LINE=$(grep "^$DOMAIN:" /etc/userdatadomains | head -1)
USERNAME=$(echo "$LINE" | awk -F'==' '{print $1}' | awk -F': ' '{print $2}' | tr -d ' ')
WP_PATH=$(echo "$LINE" | awk -F'==' '{print $5}')

if [ -z "$WP_PATH" ] || [ ! -f "$WP_PATH/wp-config.php" ]; then
  echo "❌ ไม่พบ WordPress ที่: $WP_PATH"
  exit 1
fi

echo "✅ username : $USERNAME"
echo "✅ path     : $WP_PATH"

# ===== ลบ 3 Pages =====
echo ""
echo "🗑️ กำลังลบ Pages..."
DELETED=()
NOT_FOUND=()

for SLUG in "login-2" "register-2" "contact-us-2"; do
  PAGE_ID=$(wp post list --post_type=page --name="$SLUG" --field=ID --path="$WP_PATH" --allow-root 2>/dev/null)
  if [ -n "$PAGE_ID" ]; then
    wp post delete "$PAGE_ID" --force --path="$WP_PATH" --allow-root 2>/dev/null
    echo "  ✅ ลบแล้ว: /$SLUG (ID: $PAGE_ID)"
    DELETED+=("/$SLUG")
  else
    echo "  ⚠️ ไม่พบ: /$SLUG"
    NOT_FOUND+=("/$SLUG")
  fi
done

# ===== วาง fast-redirect.php =====
MU_DIR="$WP_PATH/wp-content/mu-plugins"
mkdir -p "$MU_DIR"

if [ -f "$MU_DIR/fast-redirect.php" ]; then
  echo ""
  echo "⚠️ มีไฟล์ fast-redirect.php อยู่แล้ว → เขียนทับ"
fi

curl -s "$GITHUB_RAW/fast-redirect.php" -o "$MU_DIR/fast-redirect.php"

# ===== บันทึก Log =====
LOG_FILE="$LOG_DIR/run-$(date '+%Y%m%d').log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] run-single | $DOMAIN | $WP_PATH | ลบ: ${DELETED[*]} | ไม่พบ: ${NOT_FOUND[*]}" >> "$LOG_FILE"

# ===== แสดงผลสรุป =====
echo ""
echo "======================================"
echo "📊 สรุปผลการทำงาน"
echo "======================================"
echo "🎲 เว็บที่สุ่ม     : $DOMAIN"
echo "📁 path           : $WP_PATH"

if [ ${#DELETED[@]} -gt 0 ]; then
  echo "🗑️ ลบหน้าสำเร็จ   : ${DELETED[*]}"
fi
if [ ${#NOT_FOUND[@]} -gt 0 ]; then
  echo "⚠️ ไม่พบหน้า      : ${NOT_FOUND[*]}"
fi
echo "✅ วางไฟล์         : fast-redirect.php"

# ===== แสดงรายชื่อเว็บที่แก้ไขล่าสุดจาก Log =====
echo ""
echo "======================================"
echo "📝 รายชื่อเว็บที่แก้ไขล่าสุด (วันนี้)"
echo "======================================"
if [ -f "$LOG_FILE" ]; then
  grep "run-single" "$LOG_FILE" | awk -F'|' '{print NR". " $2}' | tail -10
else
  echo "ยังไม่มี log"
fi

echo ""
echo "🎯 ทดสอบได้ที่:"
echo "   https://$DOMAIN/login-2"
echo "   https://$DOMAIN/register-2"
echo "   https://$DOMAIN/contact-us-2"
exit 0  # ← เพิ่มบรรทัดนี้ตอนท้ายสุด
```

---

## ผลลัพธ์ที่ได้
```
======================================
🔍 กำลังค้นหาเว็บ WordPress ทั้งหมด...
======================================
🎲 สุ่มได้เว็บ: fifa8989.co
📋 จากทั้งหมด: 47 เว็บ
======================================
✅ username : armadaso
✅ path     : /home/armadaso/fifa8989.co

🗑️ กำลังลบ Pages...
  ✅ ลบแล้ว: /login-2 (ID: 42)
  ✅ ลบแล้ว: /register-2 (ID: 43)
  ✅ ลบแล้ว: /contact-us-2 (ID: 44)

======================================
📊 สรุปผลการทำงาน
======================================
🎲 เว็บที่สุ่ม     : fifa8989.co
📁 path           : /home/armadaso/fifa8989.co
🗑️ ลบหน้าสำเร็จ   : /login-2 /register-2 /contact-us-2
✅ วางไฟล์         : fast-redirect.php

======================================
📝 รายชื่อเว็บที่แก้ไขล่าสุด (วันนี้)
======================================
1. fifa8989.co
2. kingland365.pro
3. fullsloteiei.net

🎯 ทดสอบได้ที่:
   https://fifa8989.co/login-2
   https://fifa8989.co/register-2
   https://fifa8989.co/contact-us-2
