FROM tiredofit/nginx-php-fpm:8.3-alpine
ENV TIMEZONE=Asia/Shanghai
ENV VIRTUAL_PORT=80
ENV NGINX_WEBROOT=/var/www/html 
ENV CONTAINER_PROCESS_RUNAWAY_LIMIT=5
ENV LOGROTATE_COMPRESSION_TYPE=NONE
ENV LOGROTATE_RETAIN_DAYS=60
#ENV PHP_WEBROOT=docroot
ENV COLUMNS 0
ENV NGINX_SITE_ENABLED=drupal
ENV CONTAINER_ENABLE_MONITORING=FALSE
ENV PHP_ENABLE_IMAGICK=TRUE
ENV PHP_ENABLE_YAML=TRUE
ENV PHP_ENABLE_SODIUM=TRUE
ENV PHP_ENABLE_LDAP=TRUE
ENV PHP_MEMORY_LIMIT=1024M
ENV PHP_ENABLE_PGSQL=TRUE
ENV PHP_ENABLE_PDO_PGSQL=TRUE
ENV PHP_ENABLE_REDIS=TRUE
ENV PHP_ENABLE_MEMCACHED=TRUE
ENV PHP_ENABLE_BZ2=TRUE
ENV PHP_FPM_MAX_CHILDREN=300
ENV PHP_FPM_START_SERVERS=10
ENV PHP_FPM_MIN_SPARE_SERVERS=5
ENV PHP_FPM_MAX_SPARE_SERVERS=30
ENV PHP_ENABLE_CREATE_SAMPLE_PHP=FALSE
ENV NGINX_ENABLE_COMPRESSION_BROTLI=FALSE
ENV HTTP_HEADER_X_CONTENT_SECURITY_POLICY="default-src 'self' data: 'unsafe-inline' 'unsafe-eval' *.google.com *.baidu.com unpkg.com *.gstatic.com *.googleapis.com *.jsdelivr.net *.cloudflare.com d3js.org *.cookielaw.org *.youtube.com youtu.be *.youtu.be *.googleusercontent.com *.bootstrapcdn.com *.googletagmanager.com;"
ENV DRUPAL_FILES_PERM_FIXED=TRUE
ENV NGINX_ENABLE_OPEN_FILE_CACHE=FALSE
ENV CRON_DRUPAL_CRON="0 1 * * * drush -r /var/www/html/docroot/ cron"
ENV MODS_VERSION=v3
ENV S6_STAGE2_HOOK=/docker-mods
ENV NGINX_FORCE_RESET_PERMISSIONS=FALSE
ENV PATH=/var/www/html/vendor/bin:/var/www/html/bin:${PATH}

RUN apk add --no-cache zip patch && \
    php-ext enable zip && \
    ##install composer
    php -r "readfile('https://getcomposer.org/installer');" > composer-setup.php && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer && \
    ## https://github.com/linuxserver/docker-openssh-server/blob/master/Dockerfile
    echo "**** install runtime packages ****" && \
    apk add --no-cache \
        logrotate \
        nano \
        coreutils \
        shadow \
        netcat-openbsd \
        sudo && \
    echo "**** install openssh-server ****" && \
    if [ -z ${OPENSSH_RELEASE+x} ]; then \
        OPENSSH_RELEASE=$(curl -sL "http://dl-cdn.alpinelinux.org/alpine/v3.18/main/x86_64/APKINDEX.tar.gz" | tar -xz -C /tmp && \
        awk '/^P:openssh-server-pam$/,/V:/' /tmp/APKINDEX | sed -n 2p | sed 's/^V://'); \
    fi && \
    apk add --no-cache \
        openssh-client \
        openssh-server-pam \
        openssh-sftp-server && \
    echo "**** setup openssh environment ****" && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config && \
    echo "**** create abc user and make our folders ****" && \
    groupmod -g 1000 users && \
    useradd -u 911 -U -d /config -s /bin/ash abc && \
    usermod -G users abc && \
    mkdir -p \
        /app \
        /config \
        /defaults \
        /lsiopy && \
    echo "**** cleanup ****" && \
    rm -rf \
        /tmp/* \
        $HOME/.cache
COPY --from=ghcr.io/linuxserver/openssh-server:9.3_p2-r1-ls147 /etc/s6-overlay/s6-rc.d /etc/s6-overlay/s6-rc.d
ADD --chmod=744 "https://raw.githubusercontent.com/linuxserver/docker-mods/ceaf871d6d9970ae90dc35dbf189afcad0751b7f/docker-mods.v3" "/docker-mods"
ADD https://raw.githubusercontent.com/davyin-co/docker-nginx-php/main/conf/nginx/drupal.conf /etc/nginx/sites.available/drupal.conf
ADD https://raw.githubusercontent.com/davyin-co/docker-nginx-php/main/conf/nginx/laravel.conf /etc/nginx/sites.available/laravel.conf
ADD install /
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=10s CMD curl -f http://localhost/user/login || exit 1
WORKDIR /var/www/html
EXPOSE 80
