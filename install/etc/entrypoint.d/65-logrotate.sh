#!/bin/sh
#
# 65-logrotate.sh — render logrotate rules for /www/logs.
#
# Variables:
#   LOGROTATE_RETAIN_DAYS        days of rotated logs to keep (default 60)
#   LOGROTATE_COMPRESSION_TYPE   ZSTD (default, matches the nfrastack era's
#                                observed .zst output), GZIP, or NONE disables.

RETAIN_DAYS="${LOGROTATE_RETAIN_DAYS:-60}"

case "$LOGROTATE_COMPRESSION_TYPE" in
    ""|[Nn][Oo][Nn][Ee]|[Nn]one)
        COMPRESS="nocompress" ;;
    [Zz][Ss][Tt][Dd])
        COMPRESS="compress
    compresscmd /usr/bin/zstd
    compressext .zst
    compressoptions -8" ;;
    *)
        COMPRESS="compress" ;;
esac

cat > /etc/logrotate.d/custom <<EOF
/www/logs/nginx/*.log /www/logs/php/*.log {
    daily
    rotate ${RETAIN_DAYS}
    dateext
    missingok
    notifempty
    ${COMPRESS}
    copytruncate
    su root root
}
EOF

exit 0
