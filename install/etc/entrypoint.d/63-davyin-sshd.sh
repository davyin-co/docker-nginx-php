#!/bin/sh
#
# 63-davyin-sshd.sh — optional SSH server setup.
#
# Enabled when USER_NAME is set; otherwise the davyin-sshd s6 service is
# removed from the boot bundle (this script runs before /init, so editing
# /etc/s6-overlay/s6-rc.d/user/contents.d/ is still effective).
#
# Variables:
#   USER_NAME        SSH login user (created if missing; home /var/www/html)
#   PASSWORD_ACCESS  "true" enables password authentication
#   USER_PASSWORD    password for USER_NAME (PASSWORD also accepted)
#   PUBLIC_KEY       public key content for authorized_keys
#   PUBLIC_KEY_FILE  path to a file containing the public key

S6_SERVICE_LINK="/etc/s6-overlay/s6-rc.d/user/contents.d/davyin-sshd"

if [ -z "$USER_NAME" ]; then
    rm -f "$S6_SERVICE_LINK"
    exit 0
fi

echo "👉 (davyin-sshd): Enabling SSH server for user '${USER_NAME}' on port 2222"

# Host keys
mkdir -p /etc/ssh
ssh-keygen -A >/dev/null 2>&1

# Create the user if missing (shadow/useradd is installed in both variants)
if ! id "$USER_NAME" >/dev/null 2>&1; then
    useradd -u 1000 -M -d /var/www/html -s /bin/bash -G www-data "$USER_NAME" 2>/dev/null \
        || useradd -M -d /var/www/html -s /bin/bash -G www-data "$USER_NAME"
fi

SSHD_DROPIN="/etc/ssh/sshd_config.d/00-davyin.conf"

# Password authentication (opt-in via PASSWORD_ACCESS)
PASSWORD_VALUE="${USER_PASSWORD:-${PASSWORD:-}}"
case "$PASSWORD_ACCESS" in
    [Tt][Rr][Uu][Ee]|[Tt]rue|1|[Yy][Ee][Ss])
        if [ -n "$PASSWORD_VALUE" ]; then
            echo "${USER_NAME}:${PASSWORD_VALUE}" | chpasswd
            PASSWORD_SET=1
            sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' "$SSHD_DROPIN"
        else
            echo "⚠️  (davyin-sshd): PASSWORD_ACCESS=true but USER_PASSWORD is empty; keeping key-only auth"
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
# /etc/ssh/sshd_config.d/00-davyin.conf)
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
