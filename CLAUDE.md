# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository builds multi-architecture Docker images (linux/amd64, linux/arm64) for nginx + php-fpm with predefined configurations for Drupal and Laravel applications.

**Base image: `serversideup/php`**（2026-09 起，替代 nfrastack/nginx-php-fpm）。
serversideup 镜像 = 官方 PHP 镜像 + s6-overlay + install-php-extensions + 全免费的环境变量配置。
nfrastack 时代的备份见 `backup/nfrastack-base` 分支。

## Build Commands

### Alpine variant
```bash
docker build -f Dockerfile.alpine.template \
  --build-arg PHP_VERSION=8.4 \
  --build-arg UPSTREAM_VERSION=8.4-fpm-nginx-alpine \
  -t your-image-name:8.4-alpine .
```

### Debian variant
```bash
docker build -f Dockerfile.debian.template \
  --build-arg PHP_VERSION=8.4 \
  --build-arg UPSTREAM_VERSION=8.4-fpm-nginx \
  -t your-image-name:8.4-debian .
```

## Architecture

### Base Image (serversideup/php)
- Alpine: `serversideup/php:{PHP_VERSION}-fpm-nginx-alpine`
- Debian: `serversideup/php:{PHP_VERSION}-fpm-nginx`
- 关键事实（已实测验证）：
  - 默认 `USER www-data`，本镜像 Dockerfile 用 `USER root` 切回（sshd/cron 需要）
  - `NGINX_HTTP_PORT` 上游默认 **8080**，本镜像 ENV 改为 80
  - php-fpm 监听 **TCP 9000**（非 unix socket），`clear_env = no` 已内置
  - php.ini / pool 配置是 `${VAR}` 占位符模板，由 PHP/php-fpm 启动时从进程环境展开
  - php-fpm pool `pm.*` 参数（`PHP_FPM_PM_*`）原生可用，无付费锁定
  - nginx.conf 由 `10-init-webserver-config.sh` 从 `nginx.conf.template` envsubst 渲染；
    `/etc/nginx/conf.d/default.conf` 若已存在（本镜像自带 Drupal 配置）则保留不覆盖
  - s6 服务 envdir 是 `/run/s6/container_environment`（注意是下划线）
  - nginx worker 以 **nginx(80):www-data(82)** 运行（Dockerfile `usermod -u 80 -g www-data nginx`，
    对齐 nfrastack 时代属主，保证宿主机挂载日志/站点属主一致；Debian 变体为 80:33）

### Init System（s6-overlay 标准结构）
- `/etc/entrypoint.d/*.sh` 按数字序执行（每个在子 shell 中 source，**export 不会跨脚本传递**），
  全部在 `/init`（s6 启动）之前运行 → 此阶段可安全修改已渲染配置、删除 s6 contents.d 服务文件
- serversideup 自带：0-container-info、1-log-output-level、5-fpm-pool-user、5-generate-ssl、
  10-init-webserver-config、50-laravel-automations
- 本镜像的脚本（`install/etc/entrypoint.d/`）：
  - `06-davyin-compat.sh` — 旧变量名翻译：sed 替换 pool/php.ini 模板里的 `${VAR}` 占位符为具体值
  - `61-davyin-drupal.sh` — 站点配置（端口/webroot/安全头/subdir/超时/legacy 日志路径）
  - `62-davyin-cron.sh` — 渲染 crontab（Alpine `/etc/crontabs/root`；Debian `/etc/cron.d/davyin`）
  - `63-davyin-sshd.sh` — SSH 用户/密钥/host key；`USER_NAME` 为空时 `rm contents.d/davyin-sshd` 禁用服务
  - `65-davyin-logrotate.sh` — 渲染 `/etc/logrotate.d/davyin`
- 自有 s6 longrun 服务：`davyin-cron`、`davyin-sshd`
  （run 脚本用 `#!/command/execlineb -P` + `with-contenv`，调用 `/usr/local/sbin/davyin-*` 包装脚本）

### Directory Mapping
`install/` 目录通过 `ADD install /` 拷入容器：
- `install/etc/entrypoint.d/` → 初始化脚本
- `install/etc/nginx/conf.d/default.conf` → Drupal server block
- `install/etc/nginx/conf.d/drupal-maps.conf` → Boost map（http context，conf.d 在 http 级 include）
- `install/etc/nginx/extra/subdir.conf` → DRUPAL_SUBDIR(S) 运行时生成位置
- `install/etc/nginx/vhost.d/` → 用户自定义 pre-/post-*.conf 扩展点
- `install/etc/s6-overlay/s6-rc.d/` → 自有服务定义 + user/contents.d 注册
- `install/etc/ssh/sshd_config.d/00-davyin.conf` → SSH 配置（Port 2222 等）
- `install/etc/profile.d/pathenv.sh` → 登录 shell 的 PATH + PS1（红 user/青 cwd 双行提示符）
- `install/etc/bash/ps1.sh` → 非登录交互 bash 的 PS1
  （Alpine 由 /etc/bash/bashrc 的 `*.sh` 循环自动加载；Debian 由 Dockerfile 向
  /etc/bash.bashrc 追加 source 行）

### PHP / Nginx 配置路径（Alpine 与 Debian 一致）
- php.ini: `/usr/local/etc/php/conf.d/serversideup-docker-php.ini`（含 ${VAR} 占位符）
- pool: `/usr/local/etc/php-fpm.d/docker-php-serversideup-pool.conf`（含 ${VAR} 占位符）
- nginx 主配置: `/etc/nginx/nginx.conf`（启动时从 template 渲染）
- 站点配置: `/etc/nginx/conf.d/default.conf`

### PHP Extensions
构建时用 `install-php-extensions`（mlocati 工具）安装 15 个：
igbinary, msgpack, memcached, imagick, ldap, yaml, bz2,
apcu, bcmath, exif, gd, imap, intl, mysqli, pgsql
（与 nfrastack 时代对齐；基础镜像已含 redis, zip, pdo_mysql, pdo_pgsql,
sodium, opcache 等。冒烟脚本会逐项校验全部 19 个扩展）

### SSH Server
- `USER_NAME` 设置时启用（默认 ENV `USER_NAME=dsf`），监听 2222
- `63-davyin-sshd.sh` 负责建用户/host key/密钥；USER_NAME 为空时从 s6 contents.d 移除服务
- 公钥在 `/etc/ssh/authorized_keys.d/<user>`（不用 ~/.ssh：webroot 挂载卷的属主问题
  会触发 StrictModes 拒绝；且 sshd 以目标用户身份读 authorized_keys，文件必须属该用户）
- `useradd` 新建账号默认锁定（shadow 为 `!`），必须 `usermod -p '*'` 否则公钥登录也被拒

## CI/CD

GitHub Actions workflows in `.github/workflows/`:
- `docker-image.yml` - Alpine builds (PHP 8.3/8.4/8.5)
- `docker-image-debian.yml` - Debian builds (PHP 8.3/8.4/8.5)

Triggers: push to main, weekly cron, manual dispatch.
Builds and pushes to Docker Hub and Aliyun Container Registry.
基础镜像用浮动 tag（周更带安全补丁）；生产环境建议钉 `-v{serversideup版本}` tag。

## Testing

### 冒烟测试（推荐，提交前必跑）
```bash
./scripts/test-local-build.sh [PHP_VERSION] [VARIANT] [UPSTREAM_VERSION]
```
构建镜像 → 从官方 drupal 镜像的 `/opt/drupal`（含 vendor）提取代码 →
挂载并设 `DRUPAL_WEB_ROOT=web` → 验证安装页 HTTP 200。
注意：官方 drupal 镜像的 `/var/www/html` 是指向 `/opt/drupal/web` 的符号链接，
直接 cp 它会丢失 vendor/ —— 必须拷 `/opt/drupal`。

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
  -e PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  your-image-name:tag
ssh -p 2222 admin@localhost
```

## Pre-push Requirement (提交推送前必须本地测试)

任何修改 `Dockerfile.*.template`、`install/`、`.github/workflows/` 或 CI 构建矩阵的提交，在
**commit 并 push 之前** 必须完成本地构建并通过 Drupal 冒烟测试：

```bash
./scripts/test-local-build.sh 8.4 alpine        # 必测
./scripts/test-local-build.sh 8.4 debian        # 改动影响 Debian 变体时必测
./scripts/test-local-build.sh 8.3 alpine        # 涉及 PHP 版本相关逻辑时补测
```

CI 构建成功 ≠ 镜像可运行（构建只验证 Dockerfile 能跑通，不验证容器运行时）。

## Runtime Gotchas (serversideup 基座)

- **entrypoint.d 脚本在子 shell 执行**：export 不跨脚本传递，也不进 s6 服务环境。
  要改 php/pool 配置 → sed 模板占位符；要改 s6 服务环境 → 写 `/run/s6/container_environment/`
  （但该目录 /init 后才存在，entrypoint 阶段写不进去）
- **nginx.conf 在 entrypoint #10 渲染**：我们的脚本（06/61+）在其前后分工：
  06 处理 php（与 nginx 无关）；61 在 #10 之后改已渲染的 nginx.conf
- **`docker exec` / SSH 会话只有镜像 ENV 默认值**：运行时 `-e` 覆盖只影响 s6 服务进程
  （sshd 会过滤环境变量）。php.ini 占位符在 CLI 下按 ENV 默认值展开
- **PHP_CLI 的 opcache**：`PHP_OPCACHE_ENABLE=1` 同时开 cli opcache（上游行为），无实际影响
- **JIT 保持关闭**：`PHP_OPCACHE_JIT=off` + `BUFFER_SIZE=0`（Alpine/musl 上 Drupal 会 SIGSEGV）

## Common Tasks

### Adding a new PHP version
1. Add entry to matrix in `.github/workflows/docker-image.yml` (Alpine)
2. Add entry to matrix in `.github/workflows/docker-image-debian.yml` (Debian)
3. Tag 格式：alpine `{version}-fpm-nginx-alpine`；debian `{version}-fpm-nginx`

### Modifying nginx configuration
- 站点 server block: `install/etc/nginx/conf.d/default.conf`
- Drupal Boost maps: `install/etc/nginx/conf.d/drupal-maps.conf`
- http 级其他指令：可在 default.conf 同目录加 `zz-*.conf`（conf.d 在 http context include）

### Adding an init script
1. 放到 `install/etc/entrypoint.d/{NN}-davyin-{name}.sh`（POSIX sh，必须 exit 0）
2. 序号参考：serversideup 自带 0/1/5/10/50；我们的 php 类放 06，nginx 类放 61（必须在 10 之后）
3. Dockerfile 的 chmod +x 步骤会覆盖 `*-davyin-*.sh`

### Adding a long-running service
1. `install/etc/s6-overlay/s6-rc.d/davyin-{name}/`：`run`（execline + with-contenv）+ `type`（longrun）
2. 注册：`install/etc/s6-overlay/s6-rc.d/user/contents.d/davyin-{name}`（空文件）
3. 条件启动：在对应 entrypoint 脚本里 `rm contents.d/davyin-{name}`（entrypoint 先于 s6 编译运行）
