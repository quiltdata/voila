#!/bin/bash
set -euo pipefail
CONNECTION_FILE=$1
# FIXME: kernel uses unix sockets for communication with Voila. For all clients they are stored
#        in the same directory. I couldn't find easy way to share them between Voila and clients
#        without sharing them between clients.
VOILA_CONNECTION_DIR=$(python3 -c 'import os; print(os.path.dirname("'"$CONNECTION_FILE"'"))')
#SOCKET_FILE=$(python3 -c 'import json, os; print(json.load(open("'"$CONNECTION_FILE"'"))["ip"])')
cd kernel-rootfs
exec /usr/bin/bwrap \
    --new-session \
    --die-with-parent \
    --as-pid-1 \
    --unshare-user \
    --unshare-ipc \
    --unshare-pid \
    --unshare-uts \
    --unshare-cgroup \
    --unshare-net \
    --ro-bind ./usr /usr \
    --ro-bind ./etc/ /etc/ \
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
    --unsetenv HOME \
    python3 -m ipykernel_launcher -f "$CONNECTION_FILE"

