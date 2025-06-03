# -- mode: ruby --,
# vi: set ft=ruby :,

PRIVATE_NETWORK_PREFIX = "192.168.56"
Vagrant.configure("2") do |config|
  config.vm.define "attaquant" do |attaquant|
    attaquant.vm.box = "ubuntu/focal64"
    attaquant.vm.network "private_network", 
                    ip: "#{PRIVATE_NETWORK_PREFIX}.4",
                    netmask: "255.255.255.0",
                    adapter: 3

    attaquant.vm.synced_folder "./ATTAQUANT", "/home/vagrant/ATTAQUANT"
    attaquant.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update
      sudo apt-get install -y python3 apache2
      if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -b 4096 -f /home/vagrant/.ssh/id_rsa -N ""
        chown vagrant:vagrant /home/vagrant/.ssh/id_rsa*
      fi
    SHELL
  end

    config.vm.define "victime" do |victime|
    victime.vm.box = "ubuntu/focal64"
    victime.vm.network "private_network", 
                    ip: "#{PRIVATE_NETWORK_PREFIX}.5",
                    netmask: "255.255.255.0",
                    adapter: 3

    victime.vm.synced_folder "./VICTIME", "/home/vagrant/VICTIME"
    victime.vm.provision "shell", inline: <<-SHELL
      sudo apt-get update
      sudo apt-get install -y gcc
      sudo apt install encfs
      cp /vagrant/id_rsa_attaquant.pub /home/vagrant/
      cat /home/vagrant/id_rsa_attaquant.pub >> /home/vagrant/.ssh/authorized_keys
      chmod 600 /home/vagrant/.ssh/authorized_keys
      chown vagrant:vagrant /home/vagrant/.ssh/authorized_keys
      rm /home/vagrant/id_rsa_attaquant.pub
    SHELL
  end

  config.vm.provision "shell", run: "always", inline: <<-SHELL
    if [ -f /home/vagrant/.ssh/id_rsa.pub ]; then
      cp /home/vagrant/.ssh/id_rsa.pub /vagrant/id_rsa_attaquant.pub
    fi
  SHELL
end
