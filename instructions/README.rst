Tutorial Instructions
================================

There are two phases to this tutorial:

#. Migrate a M/S to PXC 
#. Topics on the working cluster


Master/Slave Migration to PXC
----------------------------------

This section covers these topics:

* Installing PXC software
* Configuring your first PXC node
* Replicating into a cluster
* SST with Xtrabackup and troubleshooting
* Consistency checking and slave lag measurements
* Monitoring Galera status

Build your environment with the Vagrantfile.master_slave and ms-setup.pl scripts::

	ln -sf Vagrantfile.master_slave Vagrantfile
	vagrant up --provider=<virtualbox|aws>
	[vagrant provision to 'fix' existing nodes]
	./ms-setup.pl

Once this is done follow the instructions in <Migrate Master Slave To Cluster.rst>.


PXC Topics
----------------

The rest of the tutorial is based on a working cluster and can be done in any order.  If you've already completed the Master/Slave migration, you should be ready to proceed.  If you want to jump ahead or correct any problems with the environment, then follow these steps::

	ln -sf Vagrantfile.baseline_cluster Vagrantfile
	vagrant up --provider=<virtualbox|aws>
	[vagrant provision to 'fix' existing nodes]
	./pxc-bootstrap.sh


Essential topics
~~~~~~~~~~~~~~~~~
* IST
* Rolling cluster config changes / software upgrades
* Application interaction with the cluster
* Monitoring Galera (myq_status, show global status, etc.)
* Online Schema Changes

Advanced topics
~~~~~~~~~~~~~~~~~

* Node failures and Arbitration
* Load balancing with HAProxy and glb
* Avoiding SST
* Monitoring and Tuning replication
* Cluster Limitations
* Autoincrement control
* Other SST methods


Crazily advanced topics
~~~~~~~~~~~~~~~~~

* Multi-Network configurations
* Xtrabackup tuning
* multicast replication
* SSL replication

