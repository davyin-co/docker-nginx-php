#!/bin/sh
#
# 60-s6-register.sh — register our s6 longrun services (cron; sshd is handled
# by 63-sshd.sh) in the base image's "user" bundle.
#
# This script runs before /init, so contents.d edits are still compiled into
# the s6 service database.
#
# Background: serversideup bases (s6-overlay >= 3.2 layout) define the user
# bundle at /etc/s6-overlay/user-bundles.d/user/contents.d/; older bases used
# /etc/s6-overlay/s6-rc.d/user/contents.d/. Defining a "user" bundle in BOTH
# locations makes them conflict — one silently wins and the upstream
# nginx/php-fpm entries get dropped from the compiled bundle (verified
# 2026-10: container started only cron+sshd, nginx/php-fpm never ran).
# So the location must be detected at runtime and exactly one used.

if [ -d /etc/s6-overlay/user-bundles.d/user/contents.d ]; then
    BUNDLE_CONTENTS=/etc/s6-overlay/user-bundles.d/user/contents.d
elif [ -d /etc/s6-overlay/s6-rc.d/user/contents.d ]; then
    BUNDLE_CONTENTS=/etc/s6-overlay/s6-rc.d/user/contents.d
else
    # Neither mechanism exists (unknown base) — create the modern one.
    mkdir -p /etc/s6-overlay/user-bundles.d/user/contents.d
    BUNDLE_CONTENTS=/etc/s6-overlay/user-bundles.d/user/contents.d
fi

# cron is unconditional; sshd is registered/removed by 63-sshd.sh.
touch "$BUNDLE_CONTENTS/cron"

exit 0
