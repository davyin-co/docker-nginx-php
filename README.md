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
      - PHP_FPM_MAX_CHILDREN=40
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
| `DRUPAL_DENY_PHP` | 生产防护：在默认 PHP 白名单基础上再禁用 install/authorize/rebuild/update 等维护入口（见下文说明） | (empty) |
| `DRUSH_SQL_EXTRA` | 注入 `drush sql:cli/connect/query/dump` 的客户端选项（`--skip-ssl` 为 MariaDB 11+ 客户端兼容，**PostgreSQL 站点须置空**，psql 不认识该选项） | `--skip-ssl` |

### PHP Configuration

PHP 的所有常用配置均由 serversideup 原生变量提供（完整列表见
[官方文档](https://serversideup.net/open-source/docker-php/docs/reference/environment-variable-specification)），本镜像的默认值。
php.ini 中的 `${VAR}` 占位符在容器启动时统一渲染为实际 env 值，
**php-fpm 与 CLI（drush / `docker exec` / SSH / cron）看到完全一致的配置**：

| Variable | Description | Default |
|----------|-------------|---------|
| `PHP_MEMORY_LIMIT` | PHP memory limit | `1024M` |
| `PHP_MAX_EXECUTION_TIME` | PHP max execution time | `180` |
| `PHP_UPLOAD_MAX_FILE_SIZE` | Max upload file size | `2G` |
| `PHP_POST_MAX_SIZE` | Max POST size | `2G` |
| `PHP_OPCACHE_ENABLE` | Enable OPcache | `1` |
| `PHP_OPCACHE_JIT` | JIT mode (`off` recommended on Alpine/musl) | `off` |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | OPcache 校验文件时间戳（部署后自动刷新代码，无需重载） | `1` |
| `PHP_FPM_PROCESS_MANAGER` | Process manager (`static`/`dynamic`/`ondemand`) | `dynamic` |
| `PHP_FPM_MAX_CHILDREN` | Max child processes | `40` |
| `PHP_FPM_START_SERVERS` | Initial server count | `4` |
| `PHP_FPM_MIN_SPARE_SERVERS` | Min spare servers | `2` |
| `PHP_FPM_MAX_SPARE_SERVERS` | Max spare servers | `8` |
| `PHP_FPM_MAX_REQUESTS` | Max requests per child before respawn | `0` |
| `TIMEOUT` | Nginx/fastcgi request timeout | (empty) |
| `PHP_LOG_LEVEL` | PHP-FPM log level | `error` |

> **说明**：`PHP_FPM_*`（nfrastack 时代的命名，DSF 平台注入的即这组）是本镜像的
> **canonical** 变量，容器启动时由 `06-compat.sh` 渲染进 pool 配置。
> serversideup 原生的 `PHP_FPM_PM_*` 变量会被本镜像的 ENV 默认值覆盖，**请勿使用**。

### 其他旧变量名兼容

以下旧变量仍可使用，容器启动时自动转换：

| Legacy (deprecated) | Canonical |
|---------------------|-----------|
| `PHP_FPM_PM` | `PHP_FPM_PROCESS_MANAGER` |
| `PHP_FPM_STATUS_ENABLE=TRUE` | fpm 开启 `/fpm-status` |
| `PHP_UPLOAD_MAX_SIZE` | `PHP_UPLOAD_MAX_FILE_SIZE` + `PHP_POST_MAX_SIZE` |
| `MAX_FILE_UPLOAD_SIZE` | 同上 + `NGINX_CLIENT_MAX_BODY_SIZE` |
| `NGINX_LOG_ACCESS_PATH` | `NGINX_ACCESS_LOG`（目录 → 拼接 `/access.log`） |
| `NGINX_LOG_ERROR_PATH` | `NGINX_ERROR_LOG`（目录 → 拼接 `/error.log`） |
| `TIMEZONE` | `PHP_DATE_TIMEZONE`（并设置系统时区） |

**已移除/失效的变量**：`NGINX_WORKER_RLIMIT_NOFILE`、`NGINX_ENABLE_COMPRESSION_BROTLI`（无 brotli 模块）、
`NGINX_ENABLE_OPEN_FILE_CACHE`、`NGINX_FORCE_RESET_PERMISSIONS`（不再递归 chown webroot）、
`ENABLE_LSYNCD` 及全部 `LSYNCD_*`（lsyncd 已移除）、`PHPFPM_POOL_*`。

### Nginx Configuration
| Variable | Description | Default |
|----------|-------------|---------|
| `NGINX_HTTP_PORT` | Custom listen port | `80` |
| `NGINX_WORKER_PROCESSES` | Worker processes (number or `auto`) | `auto` |
| `NGINX_ACCESS_LOG` | Access log file | `/www/logs/nginx/access.log` |
| `NGINX_ERROR_LOG` | Error log file | `/www/logs/nginx/error.log` |
| `NGINX_CLIENT_MAX_BODY_SIZE` | Max request body | `512M` |

### Security Headers
| Variable | Description | Default |
|----------|-------------|---------|
| `HTTP_HEADER_X_FRAME_OPTIONS` | X-Frame-Options header | `SAMEORIGIN` |
| `HTTP_HEADER_X_CONTENT_SECURITY_POLICY_ENABLE` | Enable CSP header | `FALSE` |
| `HTTP_HEADER_X_CONTENT_SECURITY_POLICY` | CSP policy value | `default-src 'self';` |

### PHP Direct-Access Allowlist（默认启用）

PHP 执行采用**白名单模型**，任何模式下都只放行明确的入口文件，其余 PHP 直连一律 404
（覆盖 `//`、`./`、`%2e`、`%2f`、大小写、PATH_INFO 等变体）：

| 模式 | 可执行的 PHP |
|------|--------------|
| 默认（`DRUPAL_DENY_PHP` 未设置或为 false） | `/index.php`、`/update.php`、`/core/install.php`、`/core/authorize.php`、`/core/rebuild.php`、`/core/modules/statistics/statistics.php` |
| `DRUPAL_DENY_PHP=true` | 仅 `/index.php` 与 `/core/modules/statistics/statistics.php` |

`DRUPAL_DENY_PHP` 只有设为 `true` / `1` / `yes` / `on`（大小写不敏感）才生效：容器启动时
把镜像内置的 `/etc/nginx/vhost.d/pre-00-deny-php.conf.disabled` 复制为
`/etc/nginx/vhost.d/pre-00-deny-php.conf`，由 `default.conf` 中已有的
`include /etc/nginx/vhost.d/pre-*.conf;` 自动带入。未设置或为其他值时启动脚本会删除该文件，
维护入口（install/authorize/rebuild/update）保持可用。

```yaml
environment:
  - DRUPAL_DENY_PHP=true   # 仅生产环境设置
```

注意：

- **这是相对旧版本的默认行为变化**：以前任意 `.php` 都可达，现在默认只放行上表入口；
  `adminer.php`、自定义 `cron.php` 等会被 404。需要自定义入口时，在
  `/etc/nginx/vhost.d/pre-10-custom.conf` 中显式添加 `location` 并
  `include /etc/nginx/fastcgi-drupal.conf;`（pre-*.conf 在兜底拒绝之前 include，可以覆盖）。
- 未安装的站点依赖 `/core/install.php`，开发/测试环境请不要设置 `DRUPAL_DENY_PHP=true`。
- `TIMEOUT` 会改写共享的 `/etc/nginx/fastcgi-drupal.conf`（所有 PHP 入口共用同一份 fastcgi 参数）。
- `/etc/nginx/vhost.d/pre-00-deny-php.conf` 是镜像**保留文件名**，请勿在该路径挂载自定义文件；
  若 vhost.d 以只读方式整体挂载，启用/关闭失败时只打印 WARN，不会中断启动。
- `DRUPAL_SUBDIR(S)` 场景下站点主体不受影响，但 `statistics.php` 的 URL 带子目录前缀，
  不在精确白名单内（会 404）。

Drupal 侧的 `settings.platform.php` 已有同名环境变量约定，建议两边取值保持一致。

### PHP 规则详解（nginx location 匹配）

本节解释上表背后的 nginx 匹配机制，便于排查"某个入口为什么 404/为什么能访问"。

#### 匹配顺序

1. **精确匹配（`=`）最先**：URI 完全相等直接命中，后续正则不再检查；
2. 没有精确命中时，按**配置文本顺序**依次匹配正则 location，**第一条命中即停止**；
3. 正则都不命中，才落到前缀 location（如 `location /` 的 `try_files`）。

`include /etc/nginx/vhost.d/pre-*.conf;` 位于 default.conf 的 server 块顶部，
因此 `pre-00-deny-php.conf` 里的正则**排在 default.conf 所有正则之前**——这是生产禁用
规则能优先于维护入口放行规则的原因。

#### default.conf 中的四类规则

```nginx
# ① 精确放行：Drupal 前端控制器（直接请求 /index.php 时仍 307）
location = /index.php {
    if ($request_uri ~* "^(.*/)index\.php(.*)") { return 307 $1$2; }
    include /etc/nginx/fastcgi-drupal.conf;
}

# ② 正则放行：维护入口（默认可用，生产可关闭）
location ~* ^/(?:core/(?:install|authorize|rebuild)|update)\.php(?:/|$) {
    include /etc/nginx/fastcgi-drupal.conf;
}

# ③ 精确放行：业务白名单
location = /core/modules/statistics/statistics.php {
    include /etc/nginx/fastcgi-drupal.conf;
}

# ④ 兜底拒绝：其余所有 PHP（含 PATH_INFO 变体）
location ~* \.php(?:/|$) {
    return 404;
}
```

- ①③ 是 `=`，优先级最高，不会被 ④ 抢走；
- ② 使用 `~*`（大小写不敏感），`(?:/|$)` 同时覆盖 `/core/install.php/x` 这类 PATH_INFO；
- ④ 同样带 `(?:/|$)`，因此 `.php` 结尾和 `.php/xxx` 都会被拒；
- **只有上述 location 会 `include /etc/nginx/fastcgi-drupal.conf`**，即只有它们能把请求
  送到 `127.0.0.1:9000`；不存在"任意 `.php` 都进 FPM"的通用 location。

#### `DRUPAL_DENY_PHP=true` 的作用

启动时把 `pre-00-deny-php.conf.disabled` 复制为 `pre-00-deny-php.conf`，片段内容只有两条：

```nginx
location ~* ^/core/(?:install|authorize|rebuild)\.php(?:/|$) { return 404; }
location ~* ^/update\.php(?:/|$) { return 404; }
```

它通过第 30 行的 include 进入 server 块，先于 ② 命中，因此 install/authorize/rebuild/update
变为 404；①③ 是精确匹配，仍然有效。开关关闭时脚本删除该文件，② 恢复生效。

#### 为什么能挡住绕过写法

nginx 在 location 匹配前会做 URL 解码、合并重复斜杠、去掉 `.`/`..` 段：

| 请求 | nginx 内部 URI |
|---|---|
| `/core//install.php` | `/core/install.php`（`merge_slashes`） |
| `/core/./install.php` | `/core/install.php`（dot 段） |
| `/core/%2e/install.php` | `/core/install.php`（解码后归一化） |
| `/core%2finstall.php` | `/core/install.php` |
| `/%63ore/install.php` | `/core/install.php` |
| `/CORE/INSTALL.PHP` | 原样，由 `~*` 大小写不敏感覆盖 |

#### 内部转发与 307

Drupal 的 `try_files ... /index.php?$query_string` 是**内部重定向**，会重新匹配到 ①；
但 `$request_uri` 仍是用户最初的 URL（如 `/node/1`），所以 ① 里的 `if` 不会触发 307——
只有用户**直接**请求 `/index.php` 时才跳转。

#### 新增自定义 PHP 入口

在 `/etc/nginx/vhost.d/pre-10-custom.conf` 中显式放行：

```nginx
location = /my-entry.php {
    include /etc/nginx/fastcgi-drupal.conf;
}
```

该文件同样在 default.conf 第 30 行被 include，早于 ④ 的兜底拒绝，因此可以覆盖；
未显式放行的 PHP 仍然 404。注意 `pre-00` 片段的 deny 正则先于用户 `pre-10` 规则，
所以无法用正则重新打开 install/update（如需临时放行，可使用精确 `=` location 覆盖）。

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
  - `06-compat.sh` — 旧变量名翻译（写具体值进 pool/php.ini 模板）
  - `61-drupal.sh` — 站点配置（端口/webroot/安全头/subdir/超时/日志路径）
  - `62-cron.sh` — 渲染 crontab（`CRON_*` + logrotate）
  - `63-sshd.sh` — SSH 用户/密钥/host key（`USER_NAME` 为空时移除服务）
  - `65-logrotate.sh` — 渲染 logrotate 规则
- 自有 s6 longrun 服务：`cron`、`sshd`（基础镜像提供 `nginx`、`php-fpm`）

### Directory Structure
```
/
├── etc/
│   ├── entrypoint.d/              # 初始化脚本（本镜像: *.sh）
│   ├── nginx/
│   │   ├── fastcgi-drupal.conf    # 共享 fastcgi 参数（TIMEOUT 在此渲染）
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

### SSH 用户 sudo 权限
登录用户默认拥有完整 sudo 权限（`/etc/sudoers.d/90-$USER_NAME`，NOPASSWD），
可直接 `sudo su -` 切换到 root。容器本身以 root 运行（`docker exec` 即可拿到
root），故此授权不引入额外风险。

### PHP can't read environment variables
php-fpm pool 已配置 `clear_env = no`。注意通过 SSH/手动 exec 的进程只能看到
镜像 ENV 默认值（sshd 会过滤环境），运行时 `-e` 覆盖仅作用于 s6 管理的服务。
但 php.ini 中的 `${VAR}` 占位符已在容器启动时（entrypoint 阶段）统一渲染为
实际值，所以 **`PHP_MEMORY_LIMIT` 等配置对 CLI / drush 同样生效**，与 php-fpm
一致。

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
