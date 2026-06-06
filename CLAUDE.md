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
