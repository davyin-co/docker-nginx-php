FROM tiredofit/nginx-php-fpm:debian-8.2
ENV TIMEZONE=Asia/Shanghai
ENV VIRTUAL_PORT=80
ENV NGINX_WEBROOT=/var/www/html 
ENV CONTAINER_PROCESS_RUNAWAY_LIMIT=5
ENV LOGROTATE_COMPRESSION_TYPE=NONE
ENV LOGROTATE_RETAIN_DAYS=60
#ENV PHP_WEBROOT=docroot
ENV DRUSH_VERSION 8.4.11
ENV DRUSH_LAUNCHER_FALLBACK=/usr/local/bin/drush8
ENV NGINX_SITE_ENABLED=drupal
ENV CONTAINER_ENABLE_MONITORING=FALSE
ENV PHP_ENABLE_IMAGICK=TRUE
ENV PHP_ENABLE_REDIS=TRUE
ENV PHP_ENABLE_MEMCACHED=TRUE
ENV PHP_MEM_LIMIT=1024M
ENV PHP_ENABLE_BZ2=TRUE
ENV PHP_FPM_MAX_CHILDREN=300
ENV PHP_FPM_START_SERVERS=10
ENV PHP_FPM_MIN_SPARE_SERVERS=5
ENV PHP_FPM_MAX_SPARE_SERVERS=30
ENV HTTP_HEADER_X_CONTENT_SECURITY_POLICY="default-src 'self' data: 'unsafe-inline' 'unsafe-eval' *.google.com *.baidu.com unpkg.com *.gstatic.com *.googleapis.com *.jsdelivr.net *.cloudflare.com d3js.org *.cookielaw.org *.youtube.com youtu.be *.youtu.be *.googleusercontent.com *.bootstrapcdn.com *.googletagmanager.com;"

RUN set -ex && \
    mkdir /var/lib/dpkg/{parts,triggers,updates,info,alternatives} && \
    apt-get update -y --allow-insecure-repositories && \
    apt-get -y install apt-transport-https lsb-release ca-certificates wget && \
    #apt-get install --force-overwrite --reinstall $(dpkg -l | grep ^ii | awk '{print $2}') && \
    apt-key adv --keyserver pgp.mit.edu --recv-keys 3A79BD29 && \
    curl -fsSL -o /tmp/mysql.deb http://repo.mysql.com/mysql-apt-config_0.8.15-1_all.deb && \
    dpkg -i /tmp/mysql.deb && \
    apt-get update -y --allow-insecure-repositories && \
    apt-get -y install apt-transport-https lsb-release ca-certificates mysql-community-client-core mysql-community-client && \
    #curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg && \
    #sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' && \
    #apt-key adv --fetch-keys 'https://packages.sury.org/php/apt.gpg' > /dev/null 2>&1 && \
    #apt-get upgrade -y && \
    #apt-get install -y --no-install-recommends wget && \
    php-ext enable zip && \
    curl -fsSL -o /usr/local/bin/drush8 https://github.com/drush-ops/drush/releases/download/$DRUSH_VERSION/drush.phar | sh && \
    chmod +x /usr/local/bin/drush8 && \
    drush8 core-status && \
    ###### Drush execute path ######
    ENV PATH=${PATH}:/var/www/html/vendor/bin
    ENV PATH=${PATH}:/var/www/html/bin
    ##install composer
    php -r "readfile('https://getcomposer.org/installer');" > composer-setup.php && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer && \
    apt-get clean -y 

ADD https://raw.githubusercontent.com/sparkpos/docker-nginx-php/master/conf/nginx/drupal.conf /etc/nginx/sites.available/drupal.conf
ADD https://raw.githubusercontent.com/sparkpos/docker-nginx-php/master/conf/nginx/laravel.conf /etc/nginx/sites.available/laravel.conf
ADD install /
WORKDIR /var/www/html
EXPOSE 80
