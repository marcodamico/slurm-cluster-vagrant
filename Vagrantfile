# -*- mode: ruby -*-
# vi: set ft=ruby :
#Define the list of machines
slurm_cluster = {
    :controller => {
        :hostname => "controller",
        :ipaddress => "10.10.10.3"
    },
    :node1 => {
        :hostname => "node1",
        :ipaddress => "10.10.10.4"
    },

    :node2 => {
        :hostname => "node2",
        :ipaddress => "10.10.10.5"
    }
}

#Provisioning inline script
$script = <<SCRIPT
apt-get update
apt-get install -y -q vim munge slurm-wlm slurmdbd environment-modules mariadb-server
echo "10.10.10.3    controller" >> /etc/hosts
echo "10.10.10.4    node1" >> /etc/hosts
echo "10.10.10.5    node2" >> /etc/hosts
ln -s /vagrant/slurm.conf /etc/slurm/slurm.conf
ln -s /vagrant/slurmdbd.conf /etc/slurm/slurmdbd.conf

SCRIPT

Vagrant.configure("2") do |global_config|
    slurm_cluster.each_pair do |name, options|
        global_config.vm.define name do |config|
            #VM configurations
            config.vm.box = "ubuntu/jammy64"
            config.vm.hostname = "#{name}"
	    config.vm.boot_timeout = 1200
            config.vm.network :private_network, ip: options[:ipaddress]
            
            #VM specifications
            config.vm.provider :virtualbox do |v|
                # v.customize ["modifyvm", :id, "--memory", "1024"]
                v.cpus = 4
                v.memory = 1024
            end

            #VM provisioning
            config.vm.provision :shell,
                :inline => $script
        end
    end
end
