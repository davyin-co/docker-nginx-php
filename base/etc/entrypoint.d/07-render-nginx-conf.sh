#!/bin/sh
# 07-render-nginx-conf.sh — render /etc/nginx/nginx.conf from
# /etc/nginx/nginx.conf.template (envsubst), the subset of serversideup's
# 10-init-webserver-config.sh that this image needs.
#
# Runs AFTER 06-compat.sh (which concretizes `worker_processes` in the
# template) and BEFORE 61-drupal.sh (which edits the rendered nginx.conf).
# /etc/nginx/conf.d/default.conf (shipped by this image) is NOT touched here,
# so the Drupal server block stays the single source of truth.
script_name="render-nginx-conf"

TEMPLATE="/etc/nginx/nginx.conf.template"
OUTPUT="/etc/nginx/nginx.conf"

if [ ! -f "$TEMPLATE" ]; then
    echo "🛑 ERROR ($script_name): $TEMPLATE not found." >&2
    exit 1
fi

if [ -e "$OUTPUT" ]; then
    echo "ℹ️ NOTICE ($script_name): $OUTPUT already exists, keeping it."
    exit 0
fi

# Restrict substitution to the variable families our template may reference
# (same prefixes as serversideup, minus the Apache/SSL-only ones).
subst_vars=$(env | grep -E '^(PHP_|NGINX_|LOG_|HEALTHCHECK_PATH)' | cut -d= -f1 | awk '{printf "${%s},",$1}' | sed 's/,$//')

echo "($script_name): Processing $TEMPLATE → $OUTPUT..."
# shellcheck disable=SC2086
envsubst "$subst_vars" < "$TEMPLATE" > "$OUTPUT"

exit 0
