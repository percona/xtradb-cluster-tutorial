Percona XtraDB Cluster Initial Setup
========

TL;DR
-------

It's a **very** good idea to do these steps *before* the tutorial session because conference WiFi tends to be unreliable at best.  At a minimum, at least do up through the step to download the centos6 box, which is several hundred MB.

1. Download and install Virtualbox from here:: (current version: 4.1.18)::
	https://www.virtualbox.org/wiki/Downloads
1. Download and install Vagrant from here:  (current version 1.0.3)::
	http://vagrantup.com
1. Keep your virtual box guest additions updated automatically::
	host> vagrant gem install vagrant-vbguest
1. Download centos6 vagrant box: (310MB) (optional, `vagrant up` will do this automatically)::
	vagrant box add centos6 https://dl.dropbox.com/u/7225008/Vagrant/CentOS-6.3-x86_64-minimal.box	
1. Get a copy of this git repository::
	git clone https://github.com/jayjanssen/pxc-tutorial
1. Run `vagrant up`::
	cd pxc-tutorial
	vagrant up
	
That should do it!

What does this actually do?
---------------------------

The basic flow of what's happening above is:

1. Downloading virtualbox -- this can run virtual machines on your laptop and supports Linux, Mac, and Windows (and is free).
1. Installing the Vagrant tool -- This tool knows how to setup and manipulate a set of VirtualBox VMs using something called a *VagrantFile*, which is somewhat analogous to a *MakeFile*.
1. Virtualbox VMs use tools installed on the GuestOS to do things like share folders with the host machine (i.e., your laptop).  This step allows Vagrant to keep those tools up to date with whatever version of VirtualBox you have.
1. Vagrant uses *boxes* for baseline OS installs to build on.  This step downloads a CentOS 6.3 minimal image and names it as the box `centos6`.  *VagrantFiles* can refer to this box when they want to build a VM.
1. You will need a local copy of all the code and configuration in this git repository on your local machine.  If you don't have/like git, you can download it a full tarball/zip file from github.
1. `vagrant up` sets up all the cluster nodes and PXC according to the rules found in the VagrantFile (and subsequent Puppet configuration).  If all goes correctly, you should have a working 3 node PXC cluster.


Things you can do with vagrant
------------------------------------

`vagrant up`
	Creates any and all nodes called for by the Vagrantfile in the current working directory and provisions them (i.e., configures them by invoking Puppet on each).

`vagrant provision`
	re-runs puppet on all your vms
	
`vagrant ssh <node>`
	ssh into <node> as the user 'vagrant'.  Use 'sudo -i' to become root.  The nodes are named `node1`, `node2`, and`node3`.
	
`vagrant suspend`
	*Suspends* the virtual machines in this working directory.  This stops the VM processes and stops them from taking up memory on your laptop.
	
`vagrant resume`
	*Resumes* all suspended virtual machines so you can continue working.

`vagrant destroy -f`
	Forcibly destroy all the VMs Vagrant has setup in this working directory (doesn't affect other Vagrant projects).  Using this and another `vagrant up` you can reset back to a baseline config, although it's usually not necessary to go this far.


To log into a node
------------------
::

	host> vagrant ssh node2
	Last login: Thu Aug  9 18:34:53 2012 from 10.0.2.2
	[vagrant@node2 ~]$ sudo -i
	[root@node2 ~]#

Notes
------

- Virtualbox *might* crash your laptop every once in a while.  If you don't like it, ask Oracle for your money back.

Terms and conventions
---------------------

PXC
	Percona XtraDB Cluster. http://www.percona.com/doc/percona-xtradb-cluster/index.html

Galera
	The technology on which PXC is based.  PXC is basically Galera + Percona Server.  See http://codership.com for more info.

wsrep
	Short for 'Work-Set Replicattor'.  You'll see this referred to in mysql settings (SHOW VARIABLES and SHOW STATUS) to for Galera items.

VirtualBox
	Oracle's Free Virtual Machine tool (analogous to VMware).  http://www.virtualbox.org
	
Vagrant
	Tool to manage and configure VMs according to a standard recipe.  http://vagrantup.com

`host>` 
	means your laptop from the root directory of the git repository
	
screen#
	Often the walkthrough instructions assume you have multiple windows or screens open so you can watch multiple things at once.  This can be a physically separate terminal window, or a unix `screen` window if you are comfortable with it.  Note that `screen` is preinstalled on the nodes for your convenience.


