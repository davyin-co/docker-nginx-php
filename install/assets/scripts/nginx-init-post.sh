#!/command/with-contenv bash
if [ ! -z "$TIMEOUT" ]; then
  sed -i "s/client_body_timeout 60;/client_body_timeout ${TIMEOUT};/g" /etc/nginx/nginx.conf
  sed -i "s/send_timeout 60;/send_timeout ${TIMEOUT};/g" /etc/nginx/nginx.conf
  sed -i "s/fastcgi_read_timeout 60;/fastcgi_read_timeout ${TIMEOUT};/g" /etc/nginx/sites.available/drupal.conf
  sed -i "s/fastcgi_read_timeout 60;/fastcgi_read_timeout ${TIMEOUT};/g" /etc/nginx/sites.enabled/drupal.conf
fi
