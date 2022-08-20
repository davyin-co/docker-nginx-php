FROM tiredofit/nginx-php-fpm:alpine-7.4
ENV TIMEZONE=Asia/Shanghai
ENV VIRTUAL_PORT=80
ENV NGINX_WEBROOT=/var/www/html 
#ENV PHP_WEBROOT=docroot
ENV DRUSH_VERSION 8.4.11
ENV DRUSH_LAUCHER 0.10.1
ENV COLUMNS 0
ENV DRUSH_LAUNCHER_FALLBACK=/usr/local/bin/drush8
ENV PS1='${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\u\[\033[00m\]@\h: \[\033[01;36m\]\w\[\033[00m\] \[\t\]\n\$ '
ENV NGINX_SITE_ENABLED=drupal
ENV CONTAINER_ENABLE_MONITORING=FALSE
ENV HTTP_HEADER_X_CONTENT_SECURITY_POLICY="default-src 'self' data: 'unsafe-inline' 'unsafe-eval' *.google.com *.baidu.com unpkg.com *.gstatic.com *.googleapis.com *.jsdelivr.net *.cloudflare.com d3js.org *.cookielaw.org *.youtube.com *.googleusercontent.com *.bootstrapcdn.com *.googletagmanager.com;"
RUN apk add --no-cache --virtual tzdata bash php7-pecl-memcached php7-pecl-redis php7-pecl-imagick && \
    php-ext enable igbinary && \
    php-ext enable memcached && \
    php-ext enable redis && \
    php-ext enable imagick && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    ###### install drush ######
    curl -fsSL -o /usr/local/bin/drush8 https://github.com/drush-ops/drush/releases/download/$DRUSH_VERSION/drush.phar | sh && \
    chmod +x /usr/local/bin/drush8 && \
    drush8 core-status && \
    ###### install drush laucher ######
    wget -O drush.phar https://github.com/drush-ops/drush-launcher/releases/download/$DRUSH_LAUCHER/drush.phar && \
    chmod +x drush.phar && \
    mv drush.phar /usr/local/bin/drush && \
    ##install composer
    php -r "readfile('https://getcomposer.org/installer');" > composer-setup.php && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer
ADD https://raw.githubusercontent.com/sparkpos/docker-nginx-php/master/conf/nginx/drupal.conf /etc/nginx/sites.available/drupal.conf
ADD install /
WORKDIR /var/www/html
EXPOSE 80
