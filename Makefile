SHELL:=/bin/bash

# Create Vagrant VMs
# copy munge authenication key from controller to node
# !! need cp -p or else munge keys do not work
setup:
	vagrant up --provider=virtualbox && \
	vagrant ssh controller -- -t 'sudo cp -p /etc/munge/munge.key /vagrant/' && \
	vagrant ssh node1 -- -t 'sudo cp -p /vagrant/munge.key /etc/munge/' && \
	vagrant ssh node1 -- -t 'sudo chown munge /etc/munge/munge.key' && \
	vagrant ssh node2 -- -t 'sudo cp -p /vagrant/munge.key /etc/munge/' && \
	vagrant ssh node2 -- -t 'sudo chown munge /etc/munge/munge.key' && \
	vagrant ssh controller -- -t 'ssh-keygen -b 2048 -t rsa -q -N "" -f /home/vagrant/.ssh/id_rsa' && \
	vagrant ssh controller -- -t 'cp /home/vagrant/.ssh/id_rsa.pub /vagrant/id_rsa.controller.pub' && \
	vagrant ssh node1 -- -t 'cat /vagrant/id_rsa.controller.pub >> .ssh/authorized_keys' && \
	vagrant ssh node2 -- -t 'cat /vagrant/id_rsa.controller.pub >> .ssh/authorized_keys' && \
	vagrant ssh node1 -- -t 'ssh-keygen -b 2048 -t rsa -q -N "" -f /home/vagrant/.ssh/id_rsa1' && \
	vagrant ssh node2 -- -t 'ssh-keygen -b 2048 -t rsa -q -N "" -f /home/vagrant/.ssh/id_rsa2' && \
	vagrant ssh node1 -- -t 'cp /home/vagrant/.ssh/id_rsa1.pub /vagrant/id_rsa.node1.pub' && \
	vagrant ssh node2 -- -t 'cp /home/vagrant/.ssh/id_rsa2.pub /vagrant/id_rsa.node2.pub' && \
	vagrant ssh controller -- -t 'cat /vagrant/id_rsa.node1.pub >> .ssh/authorized_keys' && \
	vagrant ssh controller -- -t 'cat /vagrant/id_rsa.node2.pub >> .ssh/authorized_keys' && \
	rm -f munge.key id_rsa.controller.pub id_rsa.node1.pub id_rsa.node2.pub

# make sure 'slurm' dir is writable for VMs
# start munge in both VMs
# start slurmctld, wait many seconds for it to fully start
# start slurmd
start:
	find slurm -type d -exec chmod a+rwx {} \; && \
	vagrant ssh controller -- -t 'sudo /etc/init.d/munge start; sleep 5' && \
	vagrant ssh node1 -- -t 'sudo /etc/init.d/munge start; sleep 5' && \
	vagrant ssh node2 -- -t 'sudo /etc/init.d/munge start; sleep 5' && \
	vagrant ssh controller -- -t 'sudo slurmctld; sleep 30' && \
	vagrant ssh node1 -- -t 'sudo slurmd; sleep 30' && \
	vagrant ssh node2 -- -t 'sudo slurmd; sleep 30' && \
	vagrant ssh controller -- -t 'sudo scontrol update nodename=node1 state=resume; sinfo; sleep 5'
	vagrant ssh controller -- -t 'sudo scontrol update nodename=node2 state=resume; sinfo; sleep 5'

sinfo:
	vagrant ssh controller -- -t 'sinfo'

# might need this to fix node down state?
# fix:
# 	vagrant ssh controller -- -t 'sudo scontrol update nodename=node[1-2] state=resume'

# https://slurm.schedmd.com/troubleshoot.html
# munge log: /var/log/munge/munged.log
test:
	@printf ">>> Checking munge keys on both machines\n"
	@vagrant ssh controller -- -t 'sudo md5sum /etc/munge/munge.key; sudo ls -l /etc/munge/munge.key'
	@vagrant ssh node1 -- -t 'sudo md5sum /etc/munge/munge.key; sudo ls -l /etc/munge/munge.key'
	@vagrant ssh node2 -- -t 'sudo md5sum /etc/munge/munge.key; sudo ls -l /etc/munge/munge.key'
	@printf "\n\n>>> Checking if controller can contact node (network)\n"
	@vagrant ssh controller -- -t 'ping 10.10.10.4 -c1'
	@vagrant ssh controller -- -t 'ping 10.10.10.5 -c1'
	@printf "\n\n>>> Checking if SLURM controller is running\n"
	@vagrant ssh controller -- -t 'scontrol ping'
	@printf "\n\n>>> Checking if slurmctld is running on controller\n"
	@vagrant ssh controller -- -t 'ps -el | grep slurmctld'
	@printf "\n\n>>> Checking cluster status\n"
	@vagrant ssh controller -- -t 'sinfo'
	@printf "\n\n>>> Checking if node can contact controller (network)\n"
	@vagrant ssh node1 -- -t 'ping 10.10.10.3 -c1'
	@vagrant ssh node1 -- -t 'ping 10.10.10.5 -c1'
	@vagrant ssh node2 -- -t 'ping 10.10.10.3 -c1'
	@vagrant ssh node2 -- -t 'ping 10.10.10.4 -c1'
	@printf "\n\n>>> Checking if node can contact SLURM controller\n"
	@vagrant ssh node1 -- -t 'scontrol ping'
	@vagrant ssh node2 -- -t 'scontrol ping'
	@printf "\n\n>>> Checking if slurmd is running on node\n"
	@vagrant ssh node1 -- -t 'ps -el | grep slurmd'
	@vagrant ssh node2 -- -t 'ps -el | grep slurmd'
	@printf "\n\n>>> Running a test job\n"
	@vagrant ssh controller -- -t 'sbatch --wrap="hostname"'
	@printf "\n\n>>> Running another test job\n"
	@vagrant ssh controller -- -t 'sbatch /vagrant/job.sh'
	@printf "\n\n>>> Checking node status\n"
	@vagrant ssh controller -- -t 'scontrol show nodes=node[1-2]'

# pull the plug on the VMs
stop:
	vagrant halt --force controller
	vagrant halt --force node1
	vagrant halt --force node2

# delete the VMs
remove:
	vagrant destroy controller
	vagrant destroy node1
	vagrant destroy node2

# location of the SLURM default config generators for making new conf files
get-config-html:
	vagrant ssh controller -- -t 'cp /usr/share/doc/slurmctld/*.html /vagrant/'

# get rid of the SLURM log files
clean:
	find slurm -type f ! -name ".gitkeep" -exec rm -f {} \;
