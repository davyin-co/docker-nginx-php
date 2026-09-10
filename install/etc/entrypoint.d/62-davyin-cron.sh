#!/bin/sh
#
# 62-davyin-cron.sh — render crontab from CRON_* environment variables.
#
# Every env var starting with CRON_ becomes one crontab line, e.g.:
#   CRON_DRUPAL_CRON="0 1 * * * drush -r /var/www/html/docroot/ cron"
# A daily logrotate job is always appended.
#
# Alpine (busybox crond): /etc/crontabs/root — no user column.
# Debian (cron):          /etc/cron.d/davyin — requires user column.

CRON_LINES=""
for line in $(env | grep '^CRON_' | sort | sed 's/^CRON_[^=]*=//; s/ /%20/g'); do
    CRON_LINES="${CRON_LINES}$(echo "$line" | sed 's/%20/ /g')
"
done

HEADER="SHELL=/bin/sh
PATH=/var/www/html/vendor/bin:/var/www/html/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

if [ -d /etc/crontabs ]; then
    # busybox crond (Alpine)
    {
        echo "$HEADER"
        printf '%s' "$CRON_LINES"
        # 对齐 nfrastack 时代：23:59:55 轮转，dateext 文件名日期 = 日志所属当天
        echo "59 23 * * * sleep 55; /usr/sbin/logrotate -f /etc/logrotate.conf >/dev/null 2>&1"
    } > /etc/crontabs/root
else
    # cron (Debian) — cron.d entries require the user column
    {
        echo "$HEADER"
        printf '%s' "$CRON_LINES" | sed 's/^\([^ ]* [^ ]* [^ ]* [^ ]* [^ ]* \)/\1root /'
        echo "59 23 * * * root sleep 55; /usr/sbin/logrotate -f /etc/logrotate.conf >/dev/null 2>&1"
    } > /etc/cron.d/davyin
    chmod 0644 /etc/cron.d/davyin
fi

exit 0
