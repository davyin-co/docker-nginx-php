### Overview

Build nginx+php-fpm in one docker image, with predifined nginx config for Drupal, Laravel etc.

### Usage

```bash
### quick drupal running.
docker run -d -p 8080:80 -v /path-to-your-drupal-code:/var/www/html -e APP=drupal sparkpos/docker-nginx-php:7.4-alpine

### quick drupal running.
docker run -d -p 8080:80 -v /path-to-your-drupal-code:/var/www/html -e APP=drupal -e DRUPAL_WEB_ROOT=web sparkpos/docker-nginx-php:7.4-alpine

### quick laravel running.
docker run -d -p 8080:80 -v /path-to-your-laravel-code:/var/www/html -e APP=laravel sparkpos/docker-nginx-php:7.4-alpine
```

### docker-compose example

see [docker-compose.yml](./docker-compose-example.yml)

### environment

#### General

| Name                                         | Description                                                                                                                                             | default value                                                    |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| APP                                          | the type of app, current allowed value: drupal, laravel                                                                                                 | drupal                                                           |
| HTTP_HEADER_X_FRAME_OPTIONS                  | X-Frame-Options; see[here](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Headers/X-Frame-Options)                                                      | SAMEORIGIN                                                       |
| HTTP_HEADER_X_CONTENT_SECURITY_POLICY_ENABLE | Enable Content-Security-Policy                                                                                                                          | FALSE                                                            |
| HTTP_HEADER_X_CONTENT_SECURITY_POLICY        | Content-Security-Policy, default value: "default-src 'self';";see[here](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy) |                                                                  |
| MAX_FILE_UPLOAD_SIZE                         | Modify the upload file size, this will change both the nginx & php config.                                                                              | 32M                                                              |
| LOGROTATE_RETAIN_DAYS                        | days to keep the logs,such nginx/php-fpm etc                                                                                                            | 60                                                               |
| CRON_*                                       | Name of the job value of the time and output to be run                                                                                                  | `0 2 * * * drush -r /var/www/html cron`                        |
| DRUPAL_SUBDIRS                               | multiple host and subdir                                                                                                                                | `example.com/subdir,example1.com/subdir1,example2.com/subdir2` |

#### php & php-fpm

| Name                            | Desciption                                                                    | default value |
| ------------------------------- | ----------------------------------------------------------------------------- | ------------- |
| PHP_MEMORY_LIMIT                | The php memory limit in php.ini.                                              | 1024M         |
| PHP_FPM_PM                      | modify the php-fpm processing type, allowed values: static, ondemand, dynamic | dynamic       |
| PHP_FPM_PM_MAX_CHILDREN         | modify the pm.max_children for php-fpm config.                                | 300           |
| PHP_FPM_PM_PROCESS_IDLE_TIMEOUT | modify the pm.process_idle_timeout. this is availiable when pm = ondemand     |               |
| PHP_FPM_PM_START_SERVERS        | modify the pm.start_servers. this is availiable when pm = dynamic             | 10            |
| PHP_FPM_PM_MIN_SPARE_SERVERS    | modify the pm.min_spare_servers. this is availiable when pm = dynamic         | 10            |
| PHP_FPM_PM_MAX_SPARE_SERVERS    | modify the pm.max_spare_servers. this is availiable when pm = dynamic         | 30            |
| PHP_FPM_STATUS_ENABLE           | enable the fpm status path or not. the path is /status                        | false         |
| TIMEOUT                         | modify the nginx.conf:proxy_read_timeout and php.ini:max_execution_time       | 30            |
| PHP_UPLOAD_MAX_SIZE             | file upload sise                                                              | 512M          |

#### drupal

| Name                    | Desciption                                                                                                                                               | default value |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| DRUPAL_WEB_ROOT         | for drupal project that initialized via compose, the code is located in "web". using this flag to indicate.                                              | ""            |
| DRUPAL_FILES_PERM_FIXED | fixed drupal files permission in /var/www/html/*/sites/*/files /var/www/html/sites/*/files, owner:nginx(80), group:www-data(82), files attributes: 777 | TRUE          |

#### cron support

* provide default drupal cron, run daily.
* for custom cron command, using docker volumes for different perpose
* check [here](https://github.com/sparkpos/docker-nginx-php/blob/master/conf/crontab-root) for more details.

```
/etc/periodic/min
/etc/periodic/15min
/etc/periodic/hourly
/etc/periodic/daily
/etc/periodic/weekly
/etc/periodic/monthly
```

#### lsyncd

| Name                          | Description                                                                                   | default value |
| ----------------------------- | --------------------------------------------------------------------------------------------- | ------------- |
| ENABLE_LSYNCD                 | enable lsyncd or not                                                                          | FALSE         |
| LSYNCD_TARGET                 | 1. /data/target<br />2. rsync://admin@192.168.1.1/volume                                     | """           |
| LSYNCD_TARGET_RSYNCD_PASSWORD | target rsyncd server password.<br />For multiple rsyncd server, the password must be the same | ""            |
