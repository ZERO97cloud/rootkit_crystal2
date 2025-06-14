# -*- mode: ruby -*-
# vi: set ft=ruby :
PRIVATE_NETWORK_PREFIX = "192.168.56"
INTERNAL_NETWORK_PREFIX = "10.0.3"

Vagrant.configure("2") do |config|
  
  config.vm.define "attaquant" do |attaquant|
    attaquant.vm.box = "ubuntu/focal64"
    
    # Adapter 1 : NAT par défaut de Vagrant (automatique)
    
    # Adapter 2 : Réseau privé hôte pour accès depuis la machine hôte
    attaquant.vm.network "private_network", 
                    ip: "#{PRIVATE_NETWORK_PREFIX}.4",
                    netmask: "255.255.255.0",
                    adapter: 2
    
    # Adapter 3 : Réseau interne avec IP 10.0.2.10
    attaquant.vm.network "private_network",
                    ip: "#{INTERNAL_NETWORK_PREFIX}.10",
                    netmask: "255.255.255.0",
                    virtualbox__intnet: "internal_network",
                    adapter: 3
    
    attaquant.vm.synced_folder "./ATTAQUANT", "/home/vagrant/ATTAQUANT"
    
    attaquant.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update
      sudo apt-get install -y python3 python3-pip apache2
      sudo pip install flask
      
      if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -b 4096 -f /home/vagrant/.ssh/id_rsa -N ""
        chown vagrant:vagrant /home/vagrant/.ssh/id_rsa*
      fi
      
      # Copier la clé publique pour la victime
      cp /home/vagrant/.ssh/id_rsa.pub /vagrant/id_rsa_attaquant.pub
      
      # Configuration de l'interface réseau interne
      echo "Interface réseau interne configurée sur 10.0.3.10"
      ip addr show
    SHELL
  end
  
  config.vm.define "victime" do |victime|
    victime.vm.box = "ubuntu/focal64"
    
    # Adapter 1 : NAT par défaut de Vagrant (automatique)
    
    # Adapter 2 : Réseau interne avec IP 10.0.3.11
    victime.vm.network "private_network",
                    ip: "#{INTERNAL_NETWORK_PREFIX}.11",
                    netmask: "255.255.255.0",
                    virtualbox__intnet: "internal_network",
                    adapter: 2
    
    victime.vm.synced_folder "./VICTIME", "/home/vagrant/VICTIME"
    
    victime.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update
      sudo apt-get install -y gcc make
      
      # Configuration SSH pour accès depuis attaquant
      mkdir -p /home/vagrant/.ssh
      if [ -f /vagrant/id_rsa_attaquant.pub ]; then
        cat /vagrant/id_rsa_attaquant.pub >> /home/vagrant/.ssh/authorized_keys
        chmod 600 /home/vagrant/.ssh/authorized_keys
        chown -R vagrant:vagrant /home/vagrant/.ssh
      fi
      
      # Configuration de l'interface réseau interne
      echo "Interface réseau interne configurée sur 10.0.3.20"
      ip addr show
    SHELL
  end
end
