#!/usr/bin/env python3
"""
Apply targeted patches to /container/functions/10-nginx.

Replaces the unconditional create_folder call on the webroot directory
with a conditional block gated on NGINX_FORCE_RESET_PERMISSIONS.
When the variable is FALSE, only ensures the directory exists without
changing its ownership.
"""

import sys

TARGET = "/container/functions/10-nginx"

OLD = (
    '            create_folder "${webroot_val%/}"'
    ' "${NGINX_USER}:${NGINX_GROUP}" 750\n'
    "        fi\n"
)

NEW = (
    '            if var_true "${NGINX_FORCE_RESET_PERMISSIONS}"; then\n'
    '                create_folder "${webroot_val%/}"'
    ' "${NGINX_USER}:${NGINX_GROUP}" 750\n'
    "            else\n"
    '                if [ ! -d "${webroot_val%/}" ]; then\n'
    '                    mkdir -p "${webroot_val%/}"\n'
    "                fi\n"
    '                print_debug "[configure_site/${_sitename}]'
    ' [webroot] Skipping webroot ownership reset'
    ' (NGINX_FORCE_RESET_PERMISSIONS=FALSE)"\n'
    "            fi\n"
    "        fi\n"
)


def main() -> int:
    with open(TARGET, "r") as f:
        content = f.read()

    count = content.count(OLD)
    if count == 0:
        if NEW in content or 'if var_true "${NGINX_FORCE_RESET_PERMISSIONS}"; then' in content:
            print("INFO: Patch already applied, skipping.", file=sys.stderr)
            return 0
        print("ERROR: Target pattern not found in 10-nginx!", file=sys.stderr)
        return 1
    if count > 1:
        print(f"ERROR: Target pattern found {count} times — ambiguous!", file=sys.stderr)
        return 1

    content = content.replace(OLD, NEW, 1)
    with open(TARGET, "w") as f:
        f.write(content)
    print("INFO: Patched 10-nginx — webroot create_folder now gated on NGINX_FORCE_RESET_PERMISSIONS", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
