# ps1.sh — fancy two-line prompt for interactive bash shells.
#
# Sourced by:
#   Alpine: /etc/bash/bashrc (its `for f in /etc/bash/*.sh` loop), which bash
#           reads for interactive NON-login shells (e.g. `docker exec -it … bash`)
#   Debian: appended source-line in /etc/bash.bashrc (see Dockerfile.debian)
# Login shells (SSH) already get the same PS1 from /etc/profile.d/pathenv.sh.
export PS1='${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\u\[\033[00m\]@\h: \[\033[01;36m\]\w\[\033[00m\] \[\t\]\n\$ '
