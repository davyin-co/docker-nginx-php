#!/command/with-contenv bash
#
# Nginx post-init script for timeout configuration
# Called via NGINX_POST_INIT_SCRIPT after nginx configuration is complete

if [ ! -z "$TIMEOUT" ]; then
    sed -i "s/client_body_timeout .*;/client_body_timeout ${TIMEOUT};/g" /etc/nginx/server.conf 2>/dev/null
    sed -i "s/send_timeout .*;/send_timeout ${TIMEOUT};/g" /etc/nginx/server.conf 2>/dev/null
    if [ -f /etc/nginx/sites.enabled/drupal.conf ]; then
        sed -i "s/fastcgi_read_timeout 60;/fastcgi_read_timeout ${TIMEOUT};/g" /etc/nginx/sites.enabled/drupal.conf
    fi
fi
