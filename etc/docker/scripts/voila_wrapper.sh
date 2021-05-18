#!/bin/bash
set -euo pipefail
cmd=( "$@" )
# We set voila's root dir to empty dir so it doesn't expose anything in its tree endpoint.
VOILA_ROOT_DIR=/voila-root-dir
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
    --dir $VOILA_ROOT_DIR \
    --chdir $VOILA_ROOT_DIR \
    --uid 101000 \
    --dir /var \
    --proc /proc \
    --dev /dev \
    --hostname voila-server \
    --unsetenv HOME \
    "${cmd[@]}"
