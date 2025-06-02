# -*- mode: ruby -*-
# vi: set ft=ruby :

# Préfixe du réseau privé
#PRIVATE_NETWORK_PREFIX = "192.168.56"
PRIVATE_NETWORK_PREFIX = "10.0.2"
Vagrant.configure("2") do |config|
  # Machine attaquant
  config.vm.define "attaquant" do |attaquant|
    attaquant.vm.box = "ubuntu/focal64"
    attaquant.vm.network "private_network", 
                    ip: "#{PRIVATE_NETWORK_PREFIX}.4",
                    netmask: "255.255.255.0",
                    adapter: 3

    attaquant.vm.synced_folder "./ATTAQUANT", "/home/vagrant/ATTAQUANT"
    # Génère une clé RSA sans passphrase si elle n'existe pas déjà
    attaquant.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update
      sudo apt-get install -y python3 lxde
      if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -b 4096 -f /home/vagrant/.ssh/id_rsa -N ""
        chown vagrant:vagrant /home/vagrant/.ssh/id_rsa*
      fi
    SHELL
  end

  # Machine defense
  config.vm.define "defense" do |defense|
    defense.vm.box = "ubuntu/focal64"
    defense.vm.network "private_network", 
                    ip: "#{PRIVATE_NETWORK_PREFIX}.5",
                    netmask: "255.255.255.0",
                    adapter: 3
                    
    defense.vm.synced_folder "./VICTIME", "/home/vagrant/VICTIME"
    # Récupère la clé publique de l'attaquant via le dossier partagé Vagrant
    defense.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update
      sudo apt-get install gcc
      sudo apt-get install encfs 
      cp /vagrant/id_rsa_attaquant.pub /home/vagrant/
      cat /home/vagrant/id_rsa_attaquant.pub >> /home/vagrant/.ssh/authorized_keys
      chmod 600 /home/vagrant/.ssh/authorized_keys
      chown vagrant:vagrant /home/vagrant/.ssh/authorized_keys
      rm /home/vagrant/id_rsa_attaquant.pub
    SHELL
  end

  # Provisioning global pour copier la clé publique de l'attaquant dans le dossier partagé
  config.vm.provision "shell", run: "always", inline: <<-SHELL
    if [ -f /home/vagrant/.ssh/id_rsa.pub ]; then
      cp /home/vagrant/.ssh/id_rsa.pub /vagrant/id_rsa_attaquant.pub
    fi
  SHELL
end
