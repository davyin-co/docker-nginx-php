#!/bin/sh
#
# 61-drupal.sh — Drupal site & nginx runtime configuration.
#
# Runs AFTER serversideup's 10-init-webserver-config.sh (which renders
# /etc/nginx/nginx.conf from the template), still before /init starts s6,
# so editing rendered configs here is safe.
#
# Handles:
#   NGINX_HTTP_PORT                          listen port rewrite
#   DRUPAL_WEB_ROOT / DRUPAL8_WEB_DIR        document root rewrite
#   HTTP_HEADER_X_FRAME_OPTIONS              header value rewrite
#   HTTP_HEADER_X_CONTENT_SECURITY_POLICY(+_ENABLE)  CSP header
#   DRUPAL_SUBDIR / DRUPAL_SUBDIRS           extra location blocks
#   DRUPAL_FILES_PERM_FIXED                  fix sites/default/files perms
#   TIMEOUT                                  nginx/fastcgi timeouts
#   NGINX_LOG_ACCESS_PATH / NGINX_LOG_ERROR_PATH / NGINX_LOG_BLOCKED_PATH
#                                            legacy log directory vars
#   MAX_FILE_UPLOAD_SIZE                     nginx client_max_body_size

SITE_CONF="/etc/nginx/conf.d/default.conf"
NGINX_CONF="/etc/nginx/nginx.conf"

mkdir -p /www/logs/nginx /www/logs/php

# --- Custom listen port ---
if [ -n "$NGINX_HTTP_PORT" ] && [ "$NGINX_HTTP_PORT" != "80" ]; then
    sed -i "s#listen 80;#listen $NGINX_HTTP_PORT;#g" "$SITE_CONF"
fi

# --- DRUPAL_WEB_ROOT (composer-based Drupal projects, e.g. "web") ---
DRUPAL_ROOT="${DRUPAL_WEB_ROOT:-${DRUPAL8_WEB_DIR:-}}"
if [ -n "$DRUPAL_ROOT" ]; then
    sed -i "s#root /var/www/html;#root /var/www/html/$DRUPAL_ROOT;#g" "$SITE_CONF"
fi

# --- Security headers ---
HTTP_HEADER_X_FRAME_OPTIONS="${HTTP_HEADER_X_FRAME_OPTIONS:-SAMEORIGIN}"
sed -i "s#add_header X-Frame-Options SAMEORIGIN;#add_header X-Frame-Options $HTTP_HEADER_X_FRAME_OPTIONS;#g" "$SITE_CONF"

case "$HTTP_HEADER_X_CONTENT_SECURITY_POLICY_ENABLE" in
    [Tt][Rr][Uu][Ee]|[Tt]rue|1|[Yy][Ee][Ss])
        if [ -n "$HTTP_HEADER_X_CONTENT_SECURITY_POLICY" ]; then
            sed -i "s#add_header Content-Security-Policy \"default-src 'self';\";#add_header Content-Security-Policy \"$HTTP_HEADER_X_CONTENT_SECURITY_POLICY\";#g" "$SITE_CONF"
        fi
        ;;
    *)
        sed -i '/add_header Content-Security-Policy/d' "$SITE_CONF"
        ;;
esac

# --- DRUPAL_SUBDIRS support ---
: > /etc/nginx/extra/subdir.conf

if [ -n "$DRUPAL_SUBDIR" ]; then
cat <<EOF >> /etc/nginx/extra/subdir.conf
location = /$DRUPAL_SUBDIR { try_files \$drupal_boost_subdir_try_files_homepage @redirect_$DRUPAL_SUBDIR; }
location @redirect_$DRUPAL_SUBDIR { return 301 /$DRUPAL_SUBDIR/; }
location = /$DRUPAL_SUBDIR/ { try_files \$drupal_boost_subdir_try_files_homepage @rewrite_subdir; }
location ~ ^/$DRUPAL_SUBDIR/(?!.*\\.php\$)(.*) {
  location ~* ^/$DRUPAL_SUBDIR/(.*)\\.(js|css|png|jpg|jpeg|gif|ico|svg|mp4|mkv|mov|wmv|avi)\$ {
    log_not_found off;
    add_header Pragma public;
    add_header Cache-Control "public, max-age=2592000";
    try_files /\$1.\$2 \$drupal_boost_try_files @rewrite_subdir;
  }
  try_files /\$1 \$drupal_boost_try_files @rewrite_subdir;
}
EOF
fi

if [ -n "$DRUPAL_SUBDIRS" ]; then
    OLD_IFS="$IFS"; IFS=','
    for subdir in $DRUPAL_SUBDIRS; do
        IFS="$OLD_IFS"
        subdir_value=$(echo "$subdir" | cut -d/ -f2)
        if [ -n "$subdir_value" ] && ! grep -q "location = /$subdir_value " /etc/nginx/extra/subdir.conf; then
cat <<EOF >> /etc/nginx/extra/subdir.conf
location = /$subdir_value { try_files \$drupal_boost_subdir_try_files_homepage @redirect_$subdir_value; }
location @redirect_$subdir_value { return 301 /$subdir_value/; }
location = /$subdir_value/ { try_files \$drupal_boost_subdir_try_files_homepage @rewrite_subdir; }
location ~ ^/$subdir_value/(?!.*\\.php\$)(.*) {
  location ~* ^/$subdir_value/(.*)\\.(js|css|png|jpg|jpeg|gif|ico|svg|mp4|mkv|mov|wmv|avi)\$ {
    log_not_found off;
    add_header Pragma public;
    add_header Cache-Control "public, max-age=2592000";
    try_files /\$1.\$2 \$drupal_boost_try_files @rewrite_subdir;
  }
  try_files /\$1 \$drupal_boost_try_files @rewrite_subdir;
}
EOF
        fi
        IFS=','
    done
    IFS="$OLD_IFS"
fi

# --- Timeouts ---
if [ -n "$TIMEOUT" ]; then
    sed -i "s/fastcgi_read_timeout 60;/fastcgi_read_timeout ${TIMEOUT};/g" "$SITE_CONF"
    # client_body_timeout / send_timeout are valid at http context
    cat > /etc/nginx/conf.d/zz-timeout.conf <<EOF
client_body_timeout ${TIMEOUT};
send_timeout ${TIMEOUT};
EOF
fi

# --- Legacy log directory variables ---
if [ -n "$NGINX_LOG_ACCESS_PATH" ]; then
    sed -i "s#^\([[:space:]]*access_log\)[[:space:]].*#\1  ${NGINX_LOG_ACCESS_PATH%/}/access.log main if=\$loggable;#" "$NGINX_CONF"
fi
if [ -n "$NGINX_LOG_ERROR_PATH" ]; then
    sed -i "s#^error_log[[:space:]].*#error_log  ${NGINX_LOG_ERROR_PATH%/}/error.log warn;#" "$NGINX_CONF"
fi
[ -n "$NGINX_LOG_ACCESS_PATH" ] && mkdir -p "${NGINX_LOG_ACCESS_PATH%/}"
[ -n "$NGINX_LOG_ERROR_PATH" ] && mkdir -p "${NGINX_LOG_ERROR_PATH%/}"

# --- Legacy upload size → nginx client_max_body_size ---
if [ -n "$MAX_FILE_UPLOAD_SIZE" ]; then
    sed -i "s#client_max_body_size[[:space:]].*;#client_max_body_size ${MAX_FILE_UPLOAD_SIZE};#" "$NGINX_CONF"
fi

# --- Drupal files permission fix ---
case "$DRUPAL_FILES_PERM_FIXED" in
    [Tt][Rr][Uu][Ee]|[Tt]rue|1|[Yy][Ee][Ss])
        echo "👉 (drupal): Fixing Drupal files permissions..."
        if [ -d "/var/www/html/sites/default/files" ]; then
            cd /var/www/html/sites/default/files || exit 0
            find . -not -path "*.snapshot" -mindepth 1 -maxdepth 1 -exec chown -R www-data:www-data {} + 2>/dev/null
            find . -not -path "*.snapshot" -mindepth 1 -maxdepth 1 -exec chmod -R 777 {} + 2>/dev/null
        fi
        ;;
esac

exit 0
