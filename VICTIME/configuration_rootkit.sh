#!/bin/bash
set -e


echo "Lancement de l'encodage du script"

sudo bash encodage.sh init &&

echo "Lancer le makefile du rootkit"
cd rootkit && make all && make install

exit 0