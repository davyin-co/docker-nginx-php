#!/usr/bin/env bash
#
# Local build + smoke test for docker-nginx-php images.
#
# Usage:
#   ./scripts/test-local-build.sh [PHP_VERSION] [VARIANT] [UPSTREAM_VERSION]
#
#   PHP_VERSION      8.3 | 8.4 | 8.5            (default: 8.4)
#   VARIANT          alpine | debian            (default: alpine)
#   UPSTREAM_VERSION e.g. 8.4-fpm-nginx-alpine  (default: derived from variant)
#
# Env overrides:
#   PLATFORM     build/run platform      (default: linux/amd64)
#   DRUPAL_IMAGE image to copy code from (default: drupal:11-apache)
#   PORT         host port for test      (default: 8080)
#   WAIT_SECONDS max wait for install page (default: 240; raise for cross-arch)
#
# The test copies a fresh Drupal codebase out of the official drupal image,
# mounts it into the freshly built image and verifies that nginx + php-fpm
# serve Drupal's installer page (HTTP 200 on /core/install.php). The test
# container sets DRUPAL_DENY_PHP=false because an uninstalled site needs
# the maintenance entrypoints (the image default denies them since
# 2026-11-20). A second container WITHOUT that variable must then deny
# /core/install.php and /update.php (404) — the production default.
#
set -euo pipefail

cd "$(dirname "$0")/.."

PHP_VERSION="${1:-8.4}"
VARIANT="${2:-alpine}"
UPSTREAM_VERSION="${3:-}"
PLATFORM="${PLATFORM:-linux/amd64}"
DRUPAL_IMAGE="${DRUPAL_IMAGE:-drupal:11-apache}"
PORT="${PORT:-8080}"
WAIT_SECONDS="${WAIT_SECONDS:-240}"

if [ -z "$UPSTREAM_VERSION" ]; then
    case "$VARIANT" in
        alpine) UPSTREAM_VERSION="${PHP_VERSION}-fpm-nginx-alpine" ;;
        debian) UPSTREAM_VERSION="${PHP_VERSION}-fpm-nginx" ;;
        *) echo "ERROR: unknown variant '$VARIANT' (expected alpine|debian)" >&2; exit 1 ;;
    esac
fi

DOCKERFILE="Dockerfile.${VARIANT}.template"
TAG="docker-nginx-php:test-${PHP_VERSION}-${VARIANT}"
NAME="test-nginx-php-${PHP_VERSION}-${VARIANT}-$$"
TMPDIR="$(mktemp -d)"
SRC_CONTAINER="drupal-code-src-$$"

cleanup() {
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    docker rm -f "$SRC_CONTAINER" >/dev/null 2>&1 || true
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "==> [1/5] Building ${TAG} (${DOCKERFILE}, ${PLATFORM}, upstream ${UPSTREAM_VERSION})"
docker build -f "$DOCKERFILE" \
    --platform "$PLATFORM" \
    --build-arg PHP_VERSION="$PHP_VERSION" \
    --build-arg UPSTREAM_VERSION="$UPSTREAM_VERSION" \
    -t "$TAG" .

echo "==> [2/5] Verifying PHP extensions in ${TAG}"
# Full list expected by production Drupal sites (parity with the nfrastack-era
# image): the 15 installed via install-php-extensions in the Dockerfiles plus
# redis/zip/pdo_mysql/pdo_pgsql provided by the serversideup base.
REQUIRED_EXTS="apcu bcmath bz2 exif gd igbinary imagick imap intl ldap \
memcached msgpack mysqli pdo_mysql pdo_pgsql pgsql redis yaml zip"
# Query php -m once per attempt (not per extension): repeated docker run
# invocations are slow and can fail transiently under daemon load. On busy
# daemons a run can also return truncated output, so retry a couple of times
# before declaring a failure.
missing=""
for attempt in 1 2 3; do
    PHP_MODULES="$(docker run --rm --platform "$PLATFORM" --entrypoint php "$TAG" -m 2>/dev/null)"
    missing=""
    for ext in $REQUIRED_EXTS; do
        echo "$PHP_MODULES" | grep -qix "$ext" || missing="$missing $ext"
    done
    [ -z "$missing" ] && break
    if [ "$attempt" -lt 3 ]; then
        echo "  (attempt $attempt: incomplete php -m output, missing:$missing — retrying)"
        sleep 2
    fi
done
if [ -n "$missing" ]; then
    echo "FAIL: ${TAG} missing PHP extensions:${missing}" >&2
    exit 1
fi

echo "==> [3/5] Copying Drupal codebase from ${DRUPAL_IMAGE}"
docker pull -q "$DRUPAL_IMAGE" >/dev/null
docker create --name "$SRC_CONTAINER" "$DRUPAL_IMAGE" >/dev/null
mkdir -p "$TMPDIR/html"
# The official drupal image keeps the composer project at /opt/drupal
# (vendor/, web/) and symlinks /var/www/html → /opt/drupal/web. We need the
# whole project (vendor included), so copy /opt/drupal and serve web/ via
# DRUPAL_WEB_ROOT=web.
docker cp "$SRC_CONTAINER":/opt/drupal/. "$TMPDIR/html/"
docker rm -f "$SRC_CONTAINER" >/dev/null
SRC_CONTAINER=""
[ -f "$TMPDIR/html/web/index.php" ] || { echo "ERROR: no web/index.php in drupal image code" >&2; exit 1; }

echo "==> [4/5] Starting test container ${NAME} on port ${PORT}"
docker run -d --name "$NAME" \
    --platform "$PLATFORM" \
    -p "${PORT}:80" \
    -e DRUPAL_WEB_ROOT=web \
    -e DRUPAL_DENY_PHP=false \
    -v "$TMPDIR/html:/var/www/html" \
    "$TAG" >/dev/null

echo "==> [5/5] Waiting for Drupal installer page (up to ${WAIT_SECONDS}s)"
url="http://localhost:${PORT}/core/install.php"
ok=""
for _ in $(seq 1 $((WAIT_SECONDS / 3))); do
    if curl -sfL -o /dev/null -w '%{http_code}' "$url" 2>/dev/null | grep -q '^200$'; then
        ok=1
        break
    fi
    sleep 3
done

if [ -n "$ok" ]; then
    echo "PASS: ${TAG} serves Drupal installer (HTTP 200)"
else
    echo "FAIL: ${TAG} did not serve ${url}" >&2
    echo "---- last container logs ----" >&2
    docker logs "$NAME" 2>&1 | tail -50 >&2 || true
    exit 1
fi

# --- Production-default check: without DRUPAL_DENY_PHP, maintenance ---
# --- entrypoints must be denied (404) since 2026-11-20.             ---
echo "==> [5b/5] Verifying default-deny of maintenance entrypoints"
docker rm -f "$NAME" >/dev/null
docker run -d --name "$NAME" \
    --platform "$PLATFORM" \
    -p "${PORT}:80" \
    -e DRUPAL_WEB_ROOT=web \
    -v "$TMPDIR/html:/var/www/html" \
    "$TAG" >/dev/null

deny_ok=""
for _ in $(seq 1 60); do
    code_install="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/core/install.php" 2>/dev/null || true)"
    code_update="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/update.php" 2>/dev/null || true)"
    if [ "$code_install" = "404" ] && [ "$code_update" = "404" ]; then
        deny_ok=1
        break
    fi
    if [ "$code_install" != "000" ] && [ "$code_install" != "404" ]; then
        # nginx is up but not denying — fail fast
        break
    fi
    sleep 2
done

if [ -n "$deny_ok" ]; then
    echo "PASS: default mode denies /core/install.php and /update.php (404)"
else
    echo "FAIL: default mode should deny maintenance entrypoints (got install=${code_install} update=${code_update})" >&2
    echo "---- last container logs ----" >&2
    docker logs "$NAME" 2>&1 | tail -50 >&2 || true
    exit 1
fi
