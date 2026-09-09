#!/bin/sh
#
# 65-davyin-logrotate.sh — render logrotate rules for /www/logs.
#
# Variables:
#   LOGROTATE_RETAIN_DAYS        days of rotated logs to keep (default 60)
#   LOGROTATE_COMPRESSION_TYPE   NONE disables compression (default NONE)

RETAIN_DAYS="${LOGROTATE_RETAIN_DAYS:-60}"

case "$LOGROTATE_COMPRESSION_TYPE" in
    ""|[Nn][Oo][Nn][Ee]|[Nn]one) COMPRESS="nocompress" ;;
    *)                           COMPRESS="compress" ;;
esac

cat > /etc/logrotate.d/davyin <<EOF
/www/logs/nginx/*.log /www/logs/php/*.log {
    daily
    rotate ${RETAIN_DAYS}
    missingok
    notifempty
    ${COMPRESS}
    copytruncate
    su root root
}
EOF

exit 0
