#!/bin/bash
set -euo pipefail
cmd=( "$@" )
exec /usr/bin/bwrap \
    --die-with-parent \
    --unshare-user \
    --unshare-ipc \
    --unshare-pid \
    --unshare-uts \
    --unshare-cgroup \
    --ro-bind ./kernel_wrapper.sh /kernel_wrapper.sh \
    --ro-bind ./kernel-rootfs /kernel-rootfs \
    --ro-bind ./usr /usr \
    --ro-bind ./etc/ /etc/ \
    --ro-bind /etc/resolv.conf /etc/resolv.conf \
    --symlink usr/lib /lib \
    --symlink usr/lib64 /lib64 \
    --symlink usr/bin /bin \
    --symlink usr/sbin /sbin \
    --dir /tmp \
    --uid 101000 \
    --dir /var \
    --proc /proc \
    --dev /dev \
    --hostname voila-server \
    --unsetenv HOME \
    "${cmd[@]}"
