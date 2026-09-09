# Docker Nginx + PHP-FPM

[![Docker Image CI](https://github.com/davyin-co/docker-nginx-php/actions/workflows/docker-image-debian.yml/badge.svg)](https://github.com/davyin-co/docker-nginx-php/actions/workflows/docker-image-debian.yml)
[![Alpine CI](https://github.com/davyin-co/docker-nginx-php/actions/workflows/docker-image.yml/badge.svg)](https://github.com/davyin-co/docker-nginx-php/actions/workflows/docker-image.yml)

Production-ready Docker images with Nginx + PHP-FPM, pre-configured for **Drupal** and **Laravel** applications. Built on [serversideup/php](https://serversideup.net/open-source/docker-php/) (official PHP images + s6-overlay).

> **2026-09 重构说明**：本镜像的上游已从 `nfrastack/nginx-php-fpm`（单人维护、高级功能付费锁定、接口频繁变动）迁移到 [serversideup/php](https://github.com/serversideup/docker-php)。所有运行时配置均为免费的原生环境变量，旧的 `PHP_FPM_*` 等变量名仍被兼容（见下文对照表）。

## Features

- 🚀 **Multi-architecture** support (linux/amd64, linux/arm64)
- 📦 **PHP 8.3, 8.4, 8.5** available for both Alpine and Debian
- 🔐 **Optional SSH server** - starts only when `USER_NAME` is configured
- 📝 **File logging** - nginx/php logs to `/www/logs` with logrotate
- 📊 **Rich extensions** - redis, memcached, imagick, ldap, pdo_pgsql, yaml, and more
- 🎯 **Drupal optimized** - Boost module support, subdir routing, file permissions
- 🧩 **s6-overlay** init with native environment-variable configuration

## Available Tags

### Alpine (recommended for production)
- `8.5-alpine`, `8.4-alpine`, `8.3-alpine`
- Base: `serversideup/php:{version}-fpm-nginx-alpine`

### Debian
- `8.5-debian`, `8.4-debian`, `8.3-debian`
- Base: `serversideup/php:{version}-fpm-nginx`

## Quick Start

### Basic Drupal
```bash
docker run -d \
  --name drupal-app \
  -p 8080:80 \
  -v /path/to/drupal:/var/www/html \
  davyinsa/docker-nginx-php:8.4-alpine
```

### Drupal with Composer (web root in `/web`)
```bash
docker run -d \
  --name drupal-app \
  -p 8080:80 \
  -v /path/to/drupal:/var/www/html \
  -e DRUPAL_WEB_ROOT=web \
  davyinsa/docker-nginx-php:8.4-alpine
```

### With SSH Access
```bash
docker run -d \
  --name drupal-app \
  -p 8080:80 \
  -p 2222:2222 \
  -v /path/to/drupal:/var/www/html \
  -e USER_NAME=admin \
  -e PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  davyinsa/docker-nginx-php:8.4-alpine

# Connect via SSH
ssh -p 2222 admin@localhost
```

### Docker Compose

```yaml
version: '3.8'

services:
  web:
    image: davyinsa/docker-nginx-php:8.4-alpine
    ports:
      - "8080:80"
      - "2222:2222"  # Optional: SSH
    volumes:
      - ./html:/var/www/html
      - ./logs:/www/logs
    environment:
      - DRUPAL_WEB_ROOT=web
      - USER_NAME=admin  # Optional: enables SSH
      - PHP_MEMORY_LIMIT=1024M
      - PHP_FPM_PM_MAX_CHILDREN=40
    restart: unless-stopped
```

## Environment Variables

### Application
| Variable | Description | Default |
|----------|-------------|---------|
| `DRUPAL_WEB_ROOT` | Web root relative to `/var/www/html` (e.g., `web` for Composer) | (empty) |
| `DRUPAL_SUBDIR` | Single subdirectory path | (empty) |
| `DRUPAL_SUBDIRS` | Multiple subdirectories (comma-separated) | (empty) |
| `DRUPAL_FILES_PERM_FIXED` | Fix Drupal files permissions on startup | `FALSE` |

### PHP Configuration

PHP 的所有常用配置均由 serversideup 原生变量提供（完整列表见
[官方文档](https://serversideup.net/open-source/docker-php/docs/reference/environment-variable-specification)），本镜像的默认值：

| Variable | Description | Default |
|----------|-------------|---------|
| `PHP_MEMORY_LIMIT` | PHP memory limit | `1024M` |
| `PHP_MAX_EXECUTION_TIME` | PHP max execution time | `180` |
| `PHP_UPLOAD_MAX_FILE_SIZE` | Max upload file size | `512M` |
| `PHP_POST_MAX_SIZE` | Max POST size | `512M` |
| `PHP_OPCACHE_ENABLE` | Enable OPcache | `1` |
| `PHP_OPCACHE_JIT` | JIT mode (`off` recommended on Alpine/musl) | `off` |
| `PHP_FPM_PM_CONTROL` | Process manager (`static`/`dynamic`/`ondemand`) | `dynamic` |
| `PHP_FPM_PM_MAX_CHILDREN` | Max child processes | `40` |
| `PHP_FPM_PM_START_SERVERS` | Initial server count | `4` |
| `PHP_FPM_PM_MIN_SPARE_SERVERS` | Min spare servers | `2` |
| `PHP_FPM_PM_MAX_SPARE_SERVERS` | Max spare servers | `8` |
| `PHP_FPM_PM_MAX_REQUESTS` | Max requests per child before respawn | `0` |
| `PHP_FPM_PM_STATUS_PATH` | FPM status path (e.g. `/fpm-status`) | (empty) |
| `TIMEOUT` | Nginx/fastcgi request timeout | (empty) |
| `PHP_LOG_LEVEL` | PHP-FPM log level | `error` |

### 旧变量名兼容（nfrastack 时代）

以下旧变量仍可使用，容器启动时自动转换为新变量：

| Legacy (deprecated) | Canonical |
|---------------------|-----------|
| `PHP_FPM_PM` | `PHP_FPM_PM_CONTROL` |
| `PHP_FPM_MAX_CHILDREN` | `PHP_FPM_PM_MAX_CHILDREN` |
| `PHP_FPM_START_SERVERS` | `PHP_FPM_PM_START_SERVERS` |
| `PHP_FPM_MIN_SPARE_SERVERS` | `PHP_FPM_PM_MIN_SPARE_SERVERS` |
| `PHP_FPM_MAX_SPARE_SERVERS` | `PHP_FPM_PM_MAX_SPARE_SERVERS` |
| `PHP_FPM_MAX_REQUESTS` | `PHP_FPM_PM_MAX_REQUESTS` |
| `PHP_FPM_STATUS_ENABLE=TRUE` | `PHP_FPM_PM_STATUS_PATH=/fpm-status` |
| `PHP_UPLOAD_MAX_SIZE` | `PHP_UPLOAD_MAX_FILE_SIZE` + `PHP_POST_MAX_SIZE` |
| `MAX_FILE_UPLOAD_SIZE` | 同上 + `NGINX_CLIENT_MAX_BODY_SIZE` |
| `NGINX_LOG_ACCESS_PATH` | `NGINX_ACCESS_LOG`（目录 → 拼接 `/access.log`） |
| `NGINX_LOG_ERROR_PATH` | `NGINX_ERROR_LOG`（目录 → 拼接 `/error.log`） |
| `TIMEZONE` | `PHP_DATE_TIMEZONE`（并设置系统时区） |

**已移除/失效的变量**：`NGINX_WORKER_PROCESSES`（基础镜像固定 `auto`）、
`NGINX_WORKER_RLIMIT_NOFILE`、`NGINX_ENABLE_COMPRESSION_BROTLI`（无 brotli 模块）、
`NGINX_ENABLE_OPEN_FILE_CACHE`、`NGINX_FORCE_RESET_PERMISSIONS`（不再递归 chown webroot）、
`ENABLE_LSYNCD` 及全部 `LSYNCD_*`（lsyncd 已移除）、`PHPFPM_POOL_*`。

### Nginx Configuration
| Variable | Description | Default |
|----------|-------------|---------|
| `NGINX_HTTP_PORT` | Custom listen port | `80` |
| `NGINX_ACCESS_LOG` | Access log file | `/www/logs/nginx/access.log` |
| `NGINX_ERROR_LOG` | Error log file | `/www/logs/nginx/error.log` |
| `NGINX_CLIENT_MAX_BODY_SIZE` | Max request body | `512M` |

### Security Headers
| Variable | Description | Default |
|----------|-------------|---------|
| `HTTP_HEADER_X_FRAME_OPTIONS` | X-Frame-Options header | `SAMEORIGIN` |
| `HTTP_HEADER_X_CONTENT_SECURITY_POLICY_ENABLE` | Enable CSP header | `FALSE` |
| `HTTP_HEADER_X_CONTENT_SECURITY_POLICY` | CSP policy value | `default-src 'self';` |

### SSH Server
| Variable | Description | Default |
|----------|-------------|---------|
| `USER_NAME` | SSH username (enables SSH server when set) | `dsf` |
| `PASSWORD_ACCESS` | Enable password authentication | `false` |
| `USER_PASSWORD` | SSH user password (when PASSWORD_ACCESS=true; `PASSWORD` also accepted) | (empty) |
| `PUBLIC_KEY` | Public key content for key auth | (empty) |
| `PUBLIC_KEY_FILE` | Path to a file containing the public key | (empty) |

SSH 监听 **2222** 端口。公钥写入 `/etc/ssh/authorized_keys.d/<user>`（而非
webroot 下的 `~/.ssh`，避免挂载卷权限问题）。

### Cron Jobs
Define custom cron jobs with `CRON_*` variables:

```bash
# Format: CRON_NAME="<schedule> <command>"
CRON_DRUPAL_CRON="0 * * * * drush -r /var/www/html cron"
CRON_CACHE_CLEAR="*/15 * * * * drush -r /var/www/html cache:rebuild"
```

默认已配置 `CRON_DRUPAL_CRON="0 1 * * * drush -r /var/www/html/docroot/ cron"`（如不需要可在运行时置空覆盖）以及每日 logrotate 任务。

### Logging
| Variable | Description | Default |
|----------|-------------|---------|
| `LOGROTATE_RETAIN_DAYS` | Days to keep rotated logs | `60` |
| `LOGROTATE_COMPRESSION_TYPE` | `NONE` disables compression | `NONE` |

日志文件：`/www/logs/nginx/{access,error}.log`、`/www/logs/php/error.log`。

## PHP Extensions

Pre-installed: igbinary, msgpack, memcached, imagick, ldap, yaml, bz2, plus the
serversideup defaults (redis, zip, pdo_pgsql, pdo_mysql, sodium, opcache, ...).

Adding more at image build time (see
[install-php-extensions](https://github.com/mlocati/docker-php-extension-installer#supported-php-extensions)):

```dockerfile
FROM davyinsa/docker-nginx-php:8.4-alpine
USER root
RUN install-php-extensions mongodb
```

## Architecture

### Init System
- [s6-overlay](https://github.com/just-containers/s6-overlay)（serversideup 标准结构）
- Entrypoint scripts in `/etc/entrypoint.d/`（数字序执行，先于 s6 启动）：
  - `06-davyin-compat.sh` — 旧变量名翻译（写具体值进 pool/php.ini 模板）
  - `61-davyin-drupal.sh` — 站点配置（端口/webroot/安全头/subdir/超时/日志路径）
  - `62-davyin-cron.sh` — 渲染 crontab（`CRON_*` + logrotate）
  - `63-davyin-sshd.sh` — SSH 用户/密钥/host key（`USER_NAME` 为空时移除服务）
  - `65-davyin-logrotate.sh` — 渲染 logrotate 规则
- 自有 s6 longrun 服务：`davyin-cron`、`davyin-sshd`（基础镜像提供 `nginx`、`php-fpm`）

### Directory Structure
```
/
├── etc/
│   ├── entrypoint.d/              # 初始化脚本（本镜像: *-davyin-*.sh）
│   ├── nginx/
│   │   ├── conf.d/default.conf    # Drupal server block（本镜像自带）
│   │   ├── conf.d/drupal-maps.conf# Boost map 指令（http context）
│   │   ├── extra/subdir.conf      # DRUPAL_SUBDIR(S) 运行时生成
│   │   └── vhost.d/               # 用户自定义 pre-/post-*.conf
│   ├── s6-overlay/s6-rc.d/        # 服务定义
│   └── ssh/sshd_config.d/         # SSH 配置
├── usr/local/etc/php/conf.d/      # php.ini（serversideup 模板，${VAR} 由 PHP 展开）
├── usr/local/etc/php-fpm.d/       # php-fpm pool（同上）
├── var/www/html/                  # Web root
└── www/logs/                      # 日志目录
```

## Advanced Usage

### Custom Nginx Configuration
站点的 server block 是镜像自带的 `/etc/nginx/conf.d/default.conf`。扩展点：
```bash
docker run -d \
  -v ./pre.conf:/etc/nginx/vhost.d/pre-10-custom.conf \
  -v ./post.conf:/etc/nginx/vhost.d/post-90-custom.conf \
  davyinsa/docker-nginx-php:8.4-alpine
```
http 级别的自定义（如额外 map）可挂到 `/etc/nginx/conf.d/zz-*.conf`。

### Drupal Boost Module
Boost map 指令预置在 `/etc/nginx/conf.d/drupal-maps.conf`（http context），
server block 内的 `try_files` 已接入。

### Multi-site Configuration
```bash
# Single subdirectory
DRUPAL_SUBDIR=site1

# Multiple subdirectories
DRUPAL_SUBDIRS=example.com/site1,example.com/site2,other.com/site3
```

## Building Images

### Alpine
```bash
docker build \
  -f Dockerfile.alpine.template \
  --build-arg PHP_VERSION=8.4 \
  --build-arg UPSTREAM_VERSION=8.4-fpm-nginx-alpine \
  -t my-image:8.4-alpine .
```

### Debian
```bash
docker build \
  -f Dockerfile.debian.template \
  --build-arg PHP_VERSION=8.4 \
  --build-arg UPSTREAM_VERSION=8.4-fpm-nginx \
  -t my-image:8.4-debian .
```

基础镜像 tag 规则见
[serversideup 文档](https://serversideup.net/open-source/docker-php/docs/getting-started/choosing-an-image)；
生产环境建议钉版本（如 `8.4-fpm-nginx-alpine-v4.5.1`）。

## Troubleshooting

### Container won't start
```bash
docker logs <container-name>
```

### SSH not starting
Ensure `USER_NAME` environment variable is set:
```bash
docker exec <container> env | grep USER_NAME
```

### PHP can't read environment variables
php-fpm pool 已配置 `clear_env = no`。注意通过 SSH/手动 exec 的进程只能看到
镜像 ENV 默认值（sshd 会过滤环境），运行时 `-e` 覆盖仅作用于 s6 管理的服务。

### Nginx 403 errors
Check web root permissions:
```bash
docker exec <container> ls -la /var/www/html/
```
nginx worker 以 `nginx` 用户运行、php-fpm 以 `www-data` 运行，确保文件 o+r。

### PHP-FPM not processing requests
```bash
docker exec <container> ps aux | grep php-fpm
docker exec <container> php-fpm -tt 2>&1 | grep "pm\."
```

## Support

- **Issues:** [GitHub Issues](https://github.com/davyin-co/docker-nginx-php/issues)
- **Base Image:** [serversideup/php](https://github.com/serversideup/docker-php)

## License

MIT License
