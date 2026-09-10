#!/bin/sh
#
# 06-davyin-compat.sh — canonical (nfrastack-era) environment variable handling.
#
# Runs BEFORE serversideup's 10-init-webserver-config.sh (entrypoint.d scripts
# execute in numeric order, all before /init starts s6).
#
# Why sed instead of exporting: entrypoint.d scripts run in subshells, so
# exports do not propagate, and the s6 service envdir (/run/s6/container_environment)
# does not exist yet at this stage. PHP and php-fpm natively expand ${VAR}
# placeholders from the process environment, so instead we replace the
# placeholders in the shipped config templates with concrete values.
#
# Canonical variables (nfrastack-era names, injected by the DSF platform —
# these are THE supported contract):
#   PHP_FPM_PROCESS_MANAGER / PHP_FPM_MAX_CHILDREN / PHP_FPM_START_SERVERS /
#   PHP_FPM_MIN_SPARE_SERVERS / PHP_FPM_MAX_SPARE_SERVERS / PHP_FPM_MAX_REQUESTS
#   PHP_FPM_STATUS_ENABLE / PHP_LOG_LEVEL / PHP_UPLOAD_MAX_SIZE /
#   MAX_FILE_UPLOAD_SIZE / TIMEZONE
#
# The canonical PHP_FPM_* names are baked as ENV defaults in the Dockerfile,
# so the renders below always fire and the serversideup-native PHP_FPM_PM_*
# variables are superseded (documented in README).
#
# Translations applied here:
#   PHP_FPM_PROCESS_MANAGER    → PHP_FPM_PM_CONTROL
#   PHP_FPM_MAX_CHILDREN       → PHP_FPM_PM_MAX_CHILDREN
#   PHP_FPM_START_SERVERS      → PHP_FPM_PM_START_SERVERS
#   PHP_FPM_MIN_SPARE_SERVERS  → PHP_FPM_PM_MIN_SPARE_SERVERS
#   PHP_FPM_MAX_SPARE_SERVERS  → PHP_FPM_PM_MAX_SPARE_SERVERS
#   PHP_FPM_MAX_REQUESTS       → PHP_FPM_PM_MAX_REQUESTS
#   PHP_FPM_STATUS_ENABLE=TRUE → PHP_FPM_PM_STATUS_PATH=/fpm-status
#   PHP_LOG_LEVEL              → fpm global log_level (default: error)
#   PHP_UPLOAD_MAX_SIZE        → PHP_UPLOAD_MAX_FILE_SIZE + PHP_POST_MAX_SIZE
#   MAX_FILE_UPLOAD_SIZE       → same two + nginx client_max_body_size (in 61-*)
#   TIMEZONE                   → PHP_DATE_TIMEZONE + /etc/localtime

POOL_CONF="/usr/local/etc/php-fpm.d/docker-php-serversideup-pool.conf"
PHP_INI="/usr/local/etc/php/conf.d/serversideup-docker-php.ini"

# render_pool <PLACEHOLDER_NAME> <value> — replace ${NAME} in the pool template
render_pool() {
    [ -f "$POOL_CONF" ] || return 0
    sed -i "s|\${$1}|$2|g" "$POOL_CONF"
}

# render_ini <PLACEHOLDER_NAME> <value> — replace ${NAME} in the php.ini template
render_ini() {
    [ -f "$PHP_INI" ] || return 0
    sed -i "s|\${$1}|$2|g" "$PHP_INI"
}

# --- PHP-FPM process manager (canonical PHP_FPM_* → pool placeholders) ---
# PHP_FPM_PM is accepted as an alias of PHP_FPM_PROCESS_MANAGER.
PM="${PHP_FPM_PROCESS_MANAGER:-${PHP_FPM_PM:-dynamic}}"
render_pool PHP_FPM_PM_CONTROL           "$PM"
render_pool PHP_FPM_PM_MAX_CHILDREN      "${PHP_FPM_MAX_CHILDREN:-40}"
render_pool PHP_FPM_PM_START_SERVERS     "${PHP_FPM_START_SERVERS:-4}"
render_pool PHP_FPM_PM_MIN_SPARE_SERVERS "${PHP_FPM_MIN_SPARE_SERVERS:-2}"
render_pool PHP_FPM_PM_MAX_SPARE_SERVERS "${PHP_FPM_MAX_SPARE_SERVERS:-8}"
render_pool PHP_FPM_PM_MAX_REQUESTS      "${PHP_FPM_MAX_REQUESTS:-0}"

# --- FPM status page ---
case "$PHP_FPM_STATUS_ENABLE" in
    [Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss])
        render_pool PHP_FPM_PM_STATUS_PATH "/fpm-status"
        ;;
esac

# --- FPM log level (no native serversideup variable; default error) ---
PHP_LOG_LEVEL="${PHP_LOG_LEVEL:-error}"
if [ -f "$POOL_CONF" ] && ! grep -q "^log_level" "$POOL_CONF"; then
    sed -i "/^\[global\]/a log_level = ${PHP_LOG_LEVEL}" "$POOL_CONF"
fi

# --- Upload size (legacy names → PHP_UPLOAD_MAX_FILE_SIZE / PHP_POST_MAX_SIZE) ---
UPLOAD_SIZE="${PHP_UPLOAD_MAX_SIZE:-${MAX_FILE_UPLOAD_SIZE:-}}"
if [ -n "$UPLOAD_SIZE" ]; then
    render_ini PHP_UPLOAD_MAX_FILE_SIZE "$UPLOAD_SIZE"
    render_ini PHP_POST_MAX_SIZE "$UPLOAD_SIZE"
fi

# --- Timezone ---
if [ -n "$TIMEZONE" ] && [ -z "$PHP_DATE_TIMEZONE" ]; then
    render_ini PHP_DATE_TIMEZONE "$TIMEZONE"
fi
if [ -n "$TIMEZONE" ] && [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    echo "$TIMEZONE" > /etc/timezone 2>/dev/null || true
fi

# --- Harderning: expose_php = Off (last ini directive wins) ---
if [ -f "$PHP_INI" ] && ! grep -q "^expose_php" "$PHP_INI"; then
    echo "expose_php = Off" >> "$PHP_INI"
fi

exit 0
