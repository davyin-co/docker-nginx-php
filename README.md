# Docker Nginx + PHP-FPM

[![Docker Image CI](https://github.com/davyin-co/docker-nginx-php/actions/workflows/docker-image-debian.yml/badge.svg)](https://github.com/davyin-co/docker-nginx-php/actions/workflows/docker-image-debian.yml)
[![Alpine CI](https://github.com/davyin-co/docker-nginx-php/actions/workflows/docker-image.yml/badge.svg)](https://github.com/davyin-co/docker-nginx-php/actions/workflows/docker-image.yml)

Production-ready Docker images with Nginx + PHP-FPM, pre-configured for **Drupal** and **Laravel** applications. Built on [nfrastack/nginx-php-fpm](https://hub.docker.com/r/nfrastack/nginx-php-fpm) base images with s6-overlay init system.

## Features

- 🚀 **Multi-architecture** support (linux/amd64, linux/arm64)
- 📦 **PHP 8.3, 8.4, 8.5** available for both Alpine and Debian
- 🔐 **Optional SSH server** - starts only when `USER_NAME` is configured
- 📝 **Custom log paths** - nginx and php-fpm logs configurable
- ⚡ **Fast startup** - optimized initialization with nfrastack base
- 🔄 **Real-time sync** - optional lsyncd for file synchronization
- 📊 **Rich extensions** - redis, memcached, imagick, ldap, pdo_pgsql, yaml, and more
- 🎯 **Drupal optimized** - Boost module support, subdir routing, file permissions

## Available Tags

### Alpine (recommended for production)
- `8.5-alpine`, `8.4-alpine`, `8.3-alpine`
- Based on Alpine 3.23

### Debian
- `8.5-debian` (based on Debian Trixie)
- `8.4-debian`, `8.3-debian` (based on Debian Bookworm)

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
      - PHP_FPM_MAX_CHILDREN=300
      - NGINX_LOG_ACCESS_PATH=/www/logs/nginx
      - NGINX_LOG_ERROR_PATH=/www/logs/nginx
      - PHPFPM_POOL_DEFAULT_LOG_PATH=/www/logs/nginx-php
    restart: unless-stopped
```

## Environment Variables

### Application
| Variable | Description | Default |
|----------|-------------|---------|
| `DRUPAL_WEB_ROOT` | Web root relative to `/var/www/html` (e.g., `web` for Composer) | (empty) |
| `DRUPAL_SUBDIR` | Single subdirectory path | (empty) |
| `DRUPAL_SUBDIRS` | Multiple subdirectories (comma-separated) | (empty) |
| `DRUPAL_FILES_PERM_FIXED` | Fix Drupal files permissions on startup | `TRUE` |

### PHP Configuration
| Variable | Description | Default |
|----------|-------------|---------|
| `PHP_MEMORY_LIMIT` | PHP memory limit | `1024M` |
| `PHP_UPLOAD_MAX_SIZE` | Max upload file size | `512M` |
| `PHP_FPM_PM` | Process manager type (`static`, `dynamic`, `ondemand`) | `dynamic` |
| `PHP_FPM_MAX_CHILDREN` | Max child processes | `300` |
| `PHP_FPM_START_SERVERS` | Initial server count (dynamic mode) | `10` |
| `PHP_FPM_MIN_SPARE_SERVERS` | Min spare servers (dynamic mode) | `5` |
| `PHP_FPM_MAX_SPARE_SERVERS` | Max spare servers (dynamic mode) | `30` |
| `PHP_FPM_STATUS_ENABLE` | Enable `/status` endpoint | `false` |
| `TIMEOUT` | Request timeout (nginx + PHP) | `30` |
| `PHP_LOG_LEVEL` | PHP-FPM log level | `error` |

### Nginx Configuration
| Variable | Description | Default |
|----------|-------------|---------|
| `NGINX_HTTP_PORT` | Custom listen port | `80` |
| `NGINX_LOG_ACCESS_PATH` | Access log directory | `/www/logs/nginx` |
| `NGINX_LOG_ERROR_PATH` | Error log directory | `/www/logs/nginx` |
| `NGINX_LOG_BLOCKED_PATH` | Blocked requests log directory | `/www/logs/nginx` |
| `NGINX_ENABLE_COMPRESSION_BROTLI` | Enable Brotli compression | `FALSE` |
| `NGINX_ENABLE_OPEN_FILE_CACHE` | Enable open file cache | `FALSE` |
| `MAX_FILE_UPLOAD_SIZE` | Max upload size (affects nginx + PHP) | `32M` |

### Security Headers
| Variable | Description | Default |
|----------|-------------|---------|
| `HTTP_HEADER_X_FRAME_OPTIONS` | X-Frame-Options header | `SAMEORIGIN` |
| `HTTP_HEADER_X_CONTENT_SECURITY_POLICY_ENABLE` | Enable CSP header | `FALSE` |
| `HTTP_HEADER_X_CONTENT_SECURITY_POLICY` | CSP policy value | `default-src 'self';` |

### SSH Server
| Variable | Description | Default |
|----------|-------------|---------|
| `USER_NAME` | SSH username (enables SSH server when set) | (empty) |
| `PASSWORD_ACCESS` | Enable password authentication | `false` |
| `USER_PASSWORD` | SSH user password (when PASSWORD_ACCESS=true) | (empty) |

### Real-time Sync (lsyncd)
| Variable | Description | Default |
|----------|-------------|---------|
| `ENABLE_LSYNCD` | Enable real-time file sync | `FALSE` |
| `LSYNCD_TARGET` | Sync target (local path or rsync URL) | (empty) |
| `LSYNCD_TARGET_RSYNCD_PASSWORD` | Rsync daemon password | (empty) |

### Cron Jobs
Define custom cron jobs with `CRON_*` variables:

```bash
# Format: CRON_NAME="<schedule> <command>"
CRON_DRUPAL_CRON="0 * * * * drush -r /var/www/html cron"
CRON_CACHE_CLEAR="*/15 * * * * drush -r /var/www/html cache:rebuild"
```

Predefined cron directories (Alpine):
- `/etc/periodic/15min`
- `/etc/periodic/hourly`
- `/etc/periodic/daily`
- `/etc/periodic/weekly`
- `/etc/periodic/monthly`

### Logging
| Variable | Description | Default |
|----------|-------------|---------|
| `LOGROTATE_RETAIN_DAYS` | Days to keep rotated logs | `60` |
| `LOGROTATE_COMPRESSION_TYPE` | Log compression type | `NONE` |

## PHP Extensions

### Pre-installed Extensions
**Alpine:**
- Core: igbinary, msgpack, zip, yaml
- Optional: redis, memcached, imagick, ldap, pdo_pgsql

**Debian:**
- Core: igbinary, msgpack, zip, yaml
- Optional: redis, memcached, imagick, ldap, pdo_pgsql

### Enabling Additional Extensions
Extensions can be enabled at runtime:
```bash
docker exec <container> php-ext enable <extension-name>
```

Available extensions include: amqp, apcu, bcmath, bz2, gd, gmp, intl, mongodb, and many more.

## Architecture

### Init System
Uses [s6-overlay](https://github.com/just-containers/s6-overlay) with nfrastack extensions:
- Init scripts in `/container/init/init.d/` (executed sequentially)
- Service definitions in `/container/run/available/`
- Scripts use `#!/command/with-contenv bash` shebang

### Directory Structure
```
/
├── container/
│   ├── init/init.d/          # Init scripts
│   ├── scripts/              # Helper scripts
│   └── services.available/   # Long-running services
├── etc/
│   ├── nginx/
│   │   ├── sites.available/  # Site configs
│   │   ├── sites.enabled/    # Active sites
│   │   └── server.conf.d/    # Global configs
│   ├── php{XX}/              # PHP configs (Alpine)
│   └── php/{X.Y}/            # PHP configs (Debian)
├── var/www/html/             # Web root
└── www/logs/                 # Log directory
```

### Path Differences
| Component | Alpine | Debian |
|-----------|--------|--------|
| PHP config | `/etc/php{XX}/` | `/etc/php/{X.Y}/` |
| php.ini | `/etc/php{XX}/php.ini` | `/etc/php/{X.Y}/cli/php.ini` |
| php-fpm.conf | `/etc/php{XX}/php-fpm.conf` | `/etc/php/{X.Y}/fpm/php-fpm.conf` |
| Pool config | `/etc/php{XX}/pools.d/www.conf` | `/etc/php/{X.Y}/fpm/pools.d/www.conf` |

## Advanced Usage

### Custom Nginx Configuration
Mount custom configs:
```bash
docker run -d \
  -v ./custom-nginx.conf:/etc/nginx/sites.available/custom.conf \
  -v ./custom-server.conf:/etc/nginx/server.conf.d/http/custom.conf \
  davyinsa/docker-nginx-php:8.4-alpine
```

### Drupal Boost Module
Pre-configured map directives in `/etc/nginx/server.conf.d/http/drupal-maps.conf`:
```nginx
map $http_user_agent $is_bot { ... }
map $http_x_boost_warm$http_cookie $drupal_boost_try_files { ... }
```

### Real-time File Sync
Enable lsyncd for automatic file synchronization:
```yaml
environment:
  - ENABLE_LSYNCD=TRUE
  - LSYNCD_TARGET=rsync://user@remote:/path
  - LSYNCD_TARGET_RSYNCD_PASSWORD=secret
```

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
  --build-arg UPSTREAM_VERSION=8.4-alpine_3.23 \
  -t my-image:8.4-alpine .
```

### Debian
```bash
docker build \
  -f Dockerfile.debian.template \
  --build-arg PHP_VERSION=8.4 \
  --build-arg UPSTREAM_VERSION=8.4-debian_bookworm \
  -t my-image:8.4-debian .
```

## Troubleshooting

### Container won't start
Check logs:
```bash
docker logs <container-name>
```

Common issues:
- Missing `/container/state/init/.advanced` file (should be created by Dockerfile)
- Port conflicts
- Volume mount permission issues

### SSH not starting
Ensure `USER_NAME` environment variable is set:
```bash
docker exec <container> env | grep USER_NAME
```

### PHP can't read environment variables
Verify `clear_env = no` in PHP-FPM pool config:
```bash
# Alpine
docker exec <container> grep clear_env /etc/php*/php-fpm.conf

# Debian
docker exec <container> grep clear_env /etc/php/*/fpm/pools.d/www.conf
```

### Nginx 403 errors
Check web root permissions:
```bash
docker exec <container> ls -la /var/www/html/
```

Ensure nginx user (UID 911) has read access.

### PHP-FPM not processing requests
Check PHP-FPM status:
```bash
docker exec <container> ps aux | grep php-fpm
```

Verify pool configuration:
```bash
docker exec <container> cat /etc/php/*/fpm/pools.d/www/www-settings.conf
```

## Support

- **Issues:** [GitHub Issues](https://github.com/davyin-co/docker-nginx-php/issues)
- **Base Image:** [nfrastack/nginx-php-fpm](https://hub.docker.com/r/nfrastack/nginx-php-fpm)

## License

MIT License
