#!/bin/sh
#
# 63-sshd.sh — optional SSH server setup.
#
# Enabled when USER_NAME is set; otherwise the sshd s6 service is
# removed from the boot bundle (this script runs before /init, so editing
# contents.d is still effective). The user bundle lives in one of two
# locations depending on base version — see 60-s6-register.sh.
#
# Variables:
#   USER_NAME        SSH login user (created if missing; home /var/www/html)
#   PASSWORD_ACCESS  "true" enables password authentication
#   USER_PASSWORD    password for USER_NAME (PASSWORD also accepted)
#   PUBLIC_KEY       public key content for authorized_keys
#   PUBLIC_KEY_FILE  path to a file containing the public key

NEW_BUNDLE="/etc/s6-overlay/user-bundles.d/user/contents.d/sshd"
OLD_BUNDLE="/etc/s6-overlay/s6-rc.d/user/contents.d/sshd"

if [ -z "$USER_NAME" ]; then
    rm -f "$NEW_BUNDLE" "$OLD_BUNDLE"
    exit 0
fi

echo "👉 (sshd): Enabling SSH server for user '${USER_NAME}' on port 2222"

# Register the service in the base's user bundle (same location logic as
# 60-s6-register.sh; must not define both — the two "user" bundles conflict).
if [ -d /etc/s6-overlay/user-bundles.d/user/contents.d ]; then
    touch "$NEW_BUNDLE"
else
    mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d
    touch "$OLD_BUNDLE"
fi

# Host keys
mkdir -p /etc/ssh
ssh-keygen -A >/dev/null 2>&1

# Create the user if missing (shadow/useradd is installed in both variants)
if ! id "$USER_NAME" >/dev/null 2>&1; then
    useradd -u 1000 -M -d /var/www/html -s /bin/bash -G www-data "$USER_NAME" 2>/dev/null \
        || useradd -M -d /var/www/html -s /bin/bash -G www-data "$USER_NAME"
fi

# Grant the login user full sudo. The container already runs as root (root is
# reachable via `docker exec`), so this adds no real privilege; NOPASSWD keeps
# key-only accounts (no password set) able to sudo.
SUDOERS_DROPIN="/etc/sudoers.d/90-${USER_NAME}"
echo "${USER_NAME} ALL=(ALL:ALL) NOPASSWD: ALL" > "$SUDOERS_DROPIN"
chmod 440 "$SUDOERS_DROPIN"
# Make sure the drop-in dir is actually included (both Debian and Alpine
# default sudoers do, but don't rely on it).
grep -qsE '^[@#]include(dir)?[[:space:]]+/etc/sudoers\.d' /etc/sudoers || \
    echo '@includedir /etc/sudoers.d' >> /etc/sudoers

SSHD_DROPIN="/etc/ssh/sshd_config.d/00-custom.conf"

# Password authentication (opt-in via PASSWORD_ACCESS)
PASSWORD_VALUE="${USER_PASSWORD:-${PASSWORD:-}}"
case "$PASSWORD_ACCESS" in
    [Tt][Rr][Uu][Ee]|[Tt]rue|1|[Yy][Ee][Ss])
        if [ -n "$PASSWORD_VALUE" ]; then
            echo "${USER_NAME}:${PASSWORD_VALUE}" | chpasswd
            PASSWORD_SET=1
            sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' "$SSHD_DROPIN"
        else
            echo "⚠️  (sshd): PASSWORD_ACCESS=true but USER_PASSWORD is empty; keeping key-only auth"
        fi
        ;;
esac

# useradd leaves the account locked ("!" in shadow), which makes sshd reject
# even public-key logins. "*" = no password login possible, but not locked.
# (When a password was set above the account is already unlocked.)
if [ -z "$PASSWORD_SET" ]; then
    usermod -p '*' "$USER_NAME" 2>/dev/null || true
fi

# Public key authentication (root-owned location, see AuthorizedKeysFile in
# /etc/ssh/sshd_config.d/00-custom.conf)
PUBKEY="${PUBLIC_KEY:-}"
[ -n "$PUBLIC_KEY_FILE" ] && [ -f "$PUBLIC_KEY_FILE" ] && PUBKEY="$(cat "$PUBLIC_KEY_FILE")"
if [ -n "$PUBKEY" ]; then
    mkdir -p /etc/ssh/authorized_keys.d
    echo "$PUBKEY" > "/etc/ssh/authorized_keys.d/$USER_NAME"
    chmod 755 /etc/ssh/authorized_keys.d
    # sshd reads this file AS THE USER (temporarily_use_uid), so the file
    # itself must be user-readable; the root-owned dir keeps it tamper-proof.
    chmod 600 "/etc/ssh/authorized_keys.d/$USER_NAME"
    chown "$USER_NAME:$USER_NAME" "/etc/ssh/authorized_keys.d/$USER_NAME"
fi

exit 0
