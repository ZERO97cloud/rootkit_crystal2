# -*- mode: ruby -*-
# vi: set ft=ruby :

# Configuration du Mini Rootkit Network selon le schéma réseau
# Architecture : 2 VM (Attaquant + Victime) avec réseau interne isolé + accès NAT

# Définition des préfixes réseau selon l'architecture
PRIVATE_NETWORK_PREFIX = "192.168.56"  # Réseau HOST-ONLY (accès depuis la machine hôte)
INTERNAL_NETWORK_PREFIX = "10.0.3"     # Réseau INTERNE isolé (communication VM à VM uniquement)

Vagrant.configure("2") do |config|
  
  # ===== MACHINE ATTAQUANT =====
  # VM principale qui va héberger les outils d'attaque et de contrôle
  config.vm.define "attaquant" do |attaquant|
    attaquant.vm.box = "ubuntu/focal64"
    
    # INTERFACE 1 (ETH0) : NAT par défaut - Accès Internet
    # Permet à l'attaquant d'accéder à Internet pour télécharger des outils
    
    # INTERFACE 2 (ETH1) : Réseau HOST-ONLY 192.168.56.0/24
    # Connexion avec la machine hôte pour administration et interface web
    attaquant.vm.network "private_network", 
                    ip: "#{PRIVATE_NETWORK_PREFIX}.4",        # IP : 192.168.56.4
                    netmask: "255.255.255.0",
                    adapter: 2
    
    # INTERFACE 3 (ETH2) : Réseau INTERNE 10.0.3.0/24
    # Connexion isolée avec la machine victime (pas d'accès Internet)
    attaquant.vm.network "private_network",
                    ip: "#{INTERNAL_NETWORK_PREFIX}.10",      # IP : 10.0.3.10
                    netmask: "255.255.255.0",
                    virtualbox__intnet: "internal_network",   # Réseau interne VirtualBox
                    adapter: 3
    
    # Dossier partagé pour les scripts d'attaque
    attaquant.vm.synced_folder "./attacking_program", "/home/vagrant/attacking_program"
    
    # Provisioning de la machine attaquant
    attaquant.vm.provision "shell", inline: <<-SHELL
      # Mise à jour du système
      sudo apt-get update
      
      # Installation des outils nécessaires
      sudo apt-get install -y python3 python3-pip apache2  # Serveur web + Python pour C&C
      sudo pip install flask                                # Framework web pour interface de contrôle
      
      # Génération des clés SSH pour l'accès à la victime
      if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -b 4096 -f /home/vagrant/.ssh/id_rsa -N ""
        chown vagrant:vagrant /home/vagrant/.ssh/id_rsa*
      fi
      
      # Partage de la clé publique pour injection sur la victime
      cp /home/vagrant/.ssh/id_rsa.pub /vagrant/id_rsa_attaquant.pub
      
      # Vérification de la configuration réseau
      echo "=== CONFIGURATION ATTAQUANT ==="
      echo "Interface réseau interne configurée sur 10.0.3.10"
      echo "Interface host-only configurée sur 192.168.56.4"
      ip addr show
    SHELL
  end
  
  # ===== MACHINE VICTIME =====
  # VM cible qui va être infectée par le rootkit
  config.vm.define "victime" do |victime|
    victime.vm.box = "ubuntu/focal64"
    
    # INTERFACE 1 (ETH0) : NAT par défaut - Accès Internet (sera potentiellement bloqué)
    
    # INTERFACE 2 (ETH1) : Réseau INTERNE 10.0.3.0/24
    # Seule connexion avec l'attaquant (réseau isolé, pas d'accès Internet direct)
    victime.vm.network "private_network",
                    ip: "#{INTERNAL_NETWORK_PREFIX}.11",      # IP : 10.0.3.11 (correspond à .20 dans le schéma)
                    netmask: "255.255.255.0",
                    virtualbox__intnet: "internal_network",   # Même réseau interne que l'attaquant
                    adapter: 2
    
    # Dossier partagé pour le code du rootkit
    victime.vm.synced_folder "./rootkit", "/home/vagrant/rootkit"
    
    # Provisioning de la machine victime
    victime.vm.provision "shell", inline: <<-SHELL
      # Mise à jour du système
      sudo apt-get update
      
      # Installation des outils de développement pour compiler le rootkit
      sudo apt-get install -y gcc make
      
      # Configuration SSH pour permettre l'accès depuis l'attaquant
      mkdir -p /home/vagrant/.ssh
      
      # Installation de la clé publique de l'attaquant (backdoor SSH)
      if [ -f /vagrant/id_rsa_attaquant.pub ]; then
        cat /vagrant/id_rsa_attaquant.pub >> /home/vagrant/.ssh/authorized_keys
        chmod 600 /home/vagrant/.ssh/authorized_keys
        chown -R vagrant:vagrant /home/vagrant/.ssh
        echo "Clé SSH de l'attaquant installée - Accès backdoor configuré"
      fi
      
      # Vérification de la configuration réseau
      echo "=== CONFIGURATION VICTIME ==="
      echo "Interface réseau interne configurée sur 10.0.3.11"
      echo "Machine accessible uniquement depuis le réseau interne"
      ip addr show
    SHELL
  end
end

# ===== ARCHITECTURE RÉSEAU FINALE =====
# 
# ATTAQUANT (192.168.56.4 + 10.0.3.10) :
# - ETH0 : NAT (accès Internet)
# - ETH1 : Host-Only (accès depuis l'hôte pour administration)
# - ETH2 : Réseau interne (communication avec victime)
# 
# VICTIME (10.0.3.11) :
# - ETH0 : NAT (accès Internet limité)
# - ETH1 : Réseau interne (communication avec attaquant)
# 
# TUNNEL SSH : Port 8005 -> 3000 (selon le schéma)
# Permet à l'attaquant de créer des tunnels pour exfiltrer des données
# ou maintenir la persistance même si le rootkit est détecté
