#!/usr/bin/env bash
#
# Local build + smoke test for docker-nginx-php images.
#
# Usage:
#   ./scripts/test-local-build.sh [PHP_VERSION] [VARIANT] [UPSTREAM_VERSION]
#
#   PHP_VERSION      8.3 | 8.4 | 8.5            (default: 8.4)
#   VARIANT          alpine | debian            (default: alpine)
#   UPSTREAM_VERSION e.g. 8.4-alpine_3.24       (default: derived from matrix)
#
# Env overrides:
#   PLATFORM     build/run platform      (default: linux/amd64)
#   DRUPAL_IMAGE image to copy code from (default: drupal:11-apache)
#   PORT         host port for test      (default: 8080)
#   WAIT_SECONDS max wait for install page (default: 240; raise for cross-arch)
#
# The test copies a fresh Drupal codebase out of the official drupal image,
# mounts it into the freshly built image and verifies that nginx + php-fpm
# serve Drupal's installer page (HTTP 200 on /core/install.php).
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
        alpine) UPSTREAM_VERSION="${PHP_VERSION}-alpine_3.24" ;;
        debian)
            if [ "$PHP_VERSION" = "8.5" ]; then
                UPSTREAM_VERSION="${PHP_VERSION}-debian_trixie"
            else
                UPSTREAM_VERSION="${PHP_VERSION}-debian_bookworm"
            fi
            ;;
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

echo "==> [1/4] Building ${TAG} (${DOCKERFILE}, ${PLATFORM}, upstream ${UPSTREAM_VERSION})"
docker build -f "$DOCKERFILE" \
    --platform "$PLATFORM" \
    --build-arg PHP_VERSION="$PHP_VERSION" \
    --build-arg UPSTREAM_VERSION="$UPSTREAM_VERSION" \
    -t "$TAG" .

echo "==> [2/4] Copying Drupal codebase from ${DRUPAL_IMAGE}"
docker pull -q "$DRUPAL_IMAGE" >/dev/null
docker create --name "$SRC_CONTAINER" "$DRUPAL_IMAGE" >/dev/null
mkdir -p "$TMPDIR/html"
docker cp "$SRC_CONTAINER":/var/www/html/. "$TMPDIR/html/"
docker rm -f "$SRC_CONTAINER" >/dev/null
SRC_CONTAINER=""
[ -f "$TMPDIR/html/index.php" ] || { echo "ERROR: no index.php in drupal image code" >&2; exit 1; }

echo "==> [3/4] Starting test container ${NAME} on port ${PORT}"
docker run -d --name "$NAME" \
    --platform "$PLATFORM" \
    -p "${PORT}:80" \
    -v "$TMPDIR/html:/var/www/html" \
    "$TAG" >/dev/null

echo "==> [4/4] Waiting for Drupal installer page (up to ${WAIT_SECONDS}s)"
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
