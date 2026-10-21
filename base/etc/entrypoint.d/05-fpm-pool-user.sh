#!/bin/sh
# 05-fpm-pool-user.sh — append pool user/group to the fpm pool config.
#
# Same contract as serversideup's 5-fpm-pool-user.sh (rewritten in-repo):
# appends `user`/`group` from PHP_FPM_CHILD_PROCESS_USER/GROUP to the pool
# config when running as root. 06-compat.sh renders the ${VAR} placeholders
# afterwards; the user/group lines are plain text appended here.
script_name="fpm-pool-user"

: "${PHP_FPM_CHILD_PROCESS_USER:=www-data}"
: "${PHP_FPM_CHILD_PROCESS_GROUP:=www-data}"

# Only meaningful when the fpm master runs as root
if [ "$(id -u)" -ne 0 ]; then
    exit 0
fi

if [ "${DISABLE_DEFAULT_CONFIG:-false}" = true ]; then
    exit 0
fi

POOL_CONF="/usr/local/etc/php-fpm.d/docker-php-serversideup-pool.conf"
[ -f "$POOL_CONF" ] || exit 0

if ! grep -q '^user = ' "$POOL_CONF"; then
    {
        echo ""
        echo "user = $PHP_FPM_CHILD_PROCESS_USER"
        echo "group = $PHP_FPM_CHILD_PROCESS_GROUP"
    } >> "$POOL_CONF"
fi

exit 0
