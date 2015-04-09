Preparing Conference Appliances
=======================================

#. `vagrant up`
#. `rm .vagrant/ip_cache.yml`
#. `vagrant provision --provision-with hostmanager`
#. `vagrant ssh -c "cat /etc/hosts" node[1-3]`
#. `./ms-setup.pl`
#. `./neuter-internet-repos.pl`
#. Log into nodes and verify replication is working
#. DO NOT run `vagrant halt`, this will remove entries from /etc/hosts as the vms shutdown
#. Go to Virtualbox interface and create an appliance from the nodes