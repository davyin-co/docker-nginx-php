# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository builds multi-architecture Docker images (linux/amd64, linux/arm64) for nginx + php-fpm with predefined configurations for Drupal and Laravel applications. Images are based on `nfrastack/nginx-php-fpm` (migrated from `tiredofit/nginx-php-fpm` in 2024).

## Build Commands

### Alpine variant
```bash
docker build -f Dockerfile.alpine.template \
  --build-arg PHP_VERSION=8.4 \
  --build-arg UPSTREAM_VERSION=8.4-alpine_3.23 \
  -t your-image-name:8.4-alpine .
```

### Debian variant
```bash
docker build -f Dockerfile.debian.template \
  --build-arg PHP_VERSION=8.4 \
  --build-arg UPSTREAM_VERSION=8.4-debian_bookworm \
  -t your-image-name:8.4-debian .
```

## Architecture

### Base Image
- Alpine: `nfrastack/nginx-php-fpm:{PHP_VERSION}-alpine_3.23`
- Debian: `nfrastack/nginx-php-fpm:{PHP_VERSION}-debian_{bookworm|trixie}`
- PHP 8.5 Debian uses `debian_trixie`, others use `debian_bookworm`

### Init System
Uses s6-overlay with nfrastack extensions:
- Init scripts in `/container/init/init.d/` (executed in order)
- Service definitions in `/container/run/available/`
- Init scripts must use `#!/command/with-contenv bash` shebang
- Must source `/container/base/functions/container/init` and call `prepare_service` and `liftoff`

### Directory Mapping
The `install/` directory is copied to container root via `ADD install /`:
- `install/container/init/init.d/` → `/container/init/init.d/` (init scripts)
- `install/container/scripts/` → `/container/scripts/`
- `install/container/services.available/` → `/container/services.available/` (long-running services)
- `install/etc/` → `/etc/` (nginx configs, drush, profiles)
- `install/config/` → `/config/` (lsyncd)

### PHP Configuration Paths
**Critical difference between Alpine and Debian:**
- Alpine: `/etc/php{XX}/` (e.g., `/etc/php84/php.ini`, `/etc/php84/php-fpm.conf`)
- Debian: `/etc/php/{X.Y}/` (e.g., `/etc/php/8.4/fpm/php-fpm.conf`)

Init scripts must detect paths dynamically using the pattern in `install/container/init/init.d/40-drupal`.

### Nginx Configuration
- Uses nfrastack convention: `sites.available/` and `sites.enabled/` (with dots, not dashes)
- Modular structure in `sites.enabled/{site-name}/` directory
- Custom configs via `server.conf.d/http/` for http-level directives
- Drupal Boost maps in `server.conf.d/http/drupal-maps.conf`

### SSH Server
- Integrated from `ghcr.io/linuxserver/openssh-server`
- Conditional startup: only starts when `USER_NAME` env var is set
- Alpine: sshd binary at `/usr/sbin/sshd.pam`, must patch s6 run script in Dockerfile
- Debian: sshd binary at `/usr/sbin/sshd` (no patch needed)

## CI/CD

GitHub Actions workflows in `.github/workflows/`:
- `docker-image.yml` - Alpine builds (PHP 8.3/8.4/8.5)
- `docker-image-debian.yml` - Debian builds (PHP 8.3/8.4/8.5)

Triggers: push to main, daily cron, manual dispatch.
Builds and pushes to Docker Hub and Aliyun Container Registry.

## Key Environment Variables

Runtime configuration via environment variables (see README.md for full list):
- `DRUPAL_WEB_ROOT` - Set to "web" for Composer-based Drupal projects
- `USER_NAME` - Triggers SSH server startup when set
- `PHP_FPM_*` - PHP-FPM process manager settings
- `NGINX_*` - Nginx configuration overrides
- `ENABLE_LSYNCD` - Enable real-time file sync service

## PHP Extensions

Enabled at build time via `php-ext enable` command:
- Core: igbinary, msgpack (dependencies), zip, yaml
- Optional: redis, memcached, imagick, ldap, pdo_pgsql

## Testing

### 冒烟测试（推荐，提交前必跑）
```bash
./scripts/test-local-build.sh [PHP_VERSION] [VARIANT] [UPSTREAM_VERSION]
```
构建镜像 → 从官方 drupal 镜像提取代码 → 启动容器 → 验证 Drupal 安装页返回 HTTP 200。
详见 `scripts/test-local-build.sh` 头部注释。

### Quick test
```bash
docker run -d --name test \
  -p 8080:80 \
  -v /path/to/code:/var/www/html \
  -e DRUPAL_WEB_ROOT=web \
  your-image-name:tag
```

### SSH test
```bash
docker run -d --name test-ssh \
  -p 8080:80 -p 2222:2222 \
  -e USER_NAME=admin \
  your-image-name:tag
ssh -p 2222 admin@localhost
```

## Pre-push Requirement (提交推送前必须本地测试)

任何修改 `Dockerfile.*.template`、`install/`、`.github/workflows/` 或 CI 构建矩阵的提交，在 **commit 并 push 之前** 必须完成本地构建并通过 Drupal 冒烟测试：

```bash
./scripts/test-local-build.sh 8.4 alpine        # 必测
./scripts/test-local-build.sh 8.4 debian        # 改动影响 Debian 变体时必测
./scripts/test-local-build.sh 8.3 alpine        # 涉及 PHP 版本相关逻辑时补测
```

测试脚本会用官方 `drupal:11-apache` 镜像提取 Drupal 代码，挂载到新构建的镜像中运行，
并验证 nginx + php-fpm 能正常输出 Drupal 安装页面（HTTP 200）。未通过测试的代码不得推送。

CI 构建成功 ≠ 镜像可运行（构建只验证 Dockerfile 能跑通，不验证容器运行时）。
历史教训：Alpine 3.24 升级曾引入运行时故障（见下方"容器状态目录"），CI 全绿但镜像无法启动。

## Critical Runtime Gotchas

### 不要在镜像中创建 /container/state 下的任何文件
基础镜像的 `/etc/cont-init.d/0-container` 靠 `/container/state` **不存在** 来判断首次启动。
镜像中若存在该目录（如构建时 `touch /container/state/init/.advanced`），容器首次启动会被
误判为 warm restart，初始化配置被跳过，导致 nginx 无 server.conf、php-fpm 无 pool 配置。

### PHP-FPM pool pm.* 参数被上游 Advanced 锁定
上游把默认 pool 的 `pm.*` 进程管理参数（MAX_CHILDREN/START/MIN/MAX_SPARE 等）
圈入付费 Advanced 功能：对应环境变量在初始化时被**静默重置为默认值**，
不报错、不记录。已验证 `PHPFPM_POOL_DEFAULT_*` 和旧版 `PHP_FPM_*` 别名都无效。
- 本镜像用自有 init `45-php-fpm-pool` 改写生成的 pool 配置，使 `PHP_FPM_*` 变量生效
- 自定义 pool（`PHPFPM_POOL_<NAME>_LISTEN_TYPE` 定义）不受锁定，其 pm 参数原生可用
- 备选方案：挂载 `/override/php-fpm/pool/WWW/`（目录名必须大写，上游大小写 bug）

## Common Tasks

### Adding a new PHP version
1. Add entry to matrix in `.github/workflows/docker-image.yml` (Alpine)
2. Add entry to matrix in `.github/workflows/docker-image-debian.yml` (Debian)
3. Use correct `upstream_version` tag format from nfrastack Docker Hub

### Modifying nginx configuration
- Global http-level: edit `install/etc/nginx/server.conf.d/http/*.conf`
- Site-level: edit `install/etc/nginx/sites.available/drupal.conf`
- Drupal-specific maps: edit `install/etc/nginx/server.conf.d/http/drupal-maps.conf`

### Adding a new init script
1. Create script in `install/container/init/init.d/{NN}-{name}`
2. Use naming convention: `{priority}-{name}` (e.g., `40-drupal`)
3. Include shebang, source init functions, call `prepare_service` and `liftoff`
4. Make executable: `chmod +x` (handled automatically by Dockerfile RUN command)

### Adding a long-running service
1. Create directory in `install/container/services.available/{NN}-{name}/`
2. Add `run` script with shebang and exec command
3. Control startup via init script using `service_start`/`service_stop`
