#!/bin/bash
set -euo pipefail
KERNEL_ROOTFS=/kernel-rootfs/
CONNECTION_FILE=$1
# FIXME: kernel uses unix sockets for communication with Voila. For all clients they are stored
#        in the same directory. I couldn't find easy way to share them between Voila and clients
#        without sharing them between clients.
VOILA_CONNECTION_DIR=$(python3 -c 'import os; print(os.path.dirname("'"$CONNECTION_FILE"'"))')
#SOCKET_FILE=$(python3 -c 'import json, os; print(json.load(open("'"$CONNECTION_FILE"'"))["ip"])')
NEW_HOME=/home/voila-kernel
exec env -i /usr/bin/bwrap \
    --new-session \
    --die-with-parent \
    --as-pid-1 \
    --unshare-user \
    --unshare-ipc \
    --unshare-pid \
    --unshare-uts \
    --unshare-cgroup \
    --ro-bind $KERNEL_ROOTFS/usr /usr \
    --ro-bind $KERNEL_ROOTFS/etc/ /etc/ \
    --ro-bind /etc/resolv.conf /etc/resolv.conf \
    --symlink usr/lib /lib \
    --symlink usr/lib64 /lib64 \
    --symlink usr/bin /bin \
    --symlink usr/sbin /sbin \
    --dir /tmp \
    --uid 201000 \
    --dir /var \
    --proc /proc \
    --dev /dev \
    --hostname voila-kernel \
    --bind "$VOILA_CONNECTION_DIR" "$VOILA_CONNECTION_DIR" \
    --dir $NEW_HOME \
    --setenv HOME $NEW_HOME \
    --dir $NEW_HOME/.local/lib/python3.8/site-packages \
    --setenv PATH $PATH:$NEW_HOME/.local/bin \
    --setenv AWS_ACCESS_KEY_ID "$AWS_ACCESS_KEY_ID" \
    --setenv AWS_SECRET_ACCESS_KEY "$AWS_SECRET_ACCESS_KEY" \
    --setenv AWS_SESSION_TOKEN "$AWS_SESSION_TOKEN" \
    --setenv QUILT_PKG_BUCKET "$QUILT_PKG_BUCKET" \
    --setenv QUILT_PKG_NAME "$QUILT_PKG_NAME" \
    --setenv QUILT_PKG_TOP_HASH "$QUILT_PKG_TOP_HASH" \
    python3 -m ipykernel_launcher --colors=NoColor -f "$CONNECTION_FILE"

