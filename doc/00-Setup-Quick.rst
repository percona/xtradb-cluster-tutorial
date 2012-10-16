Percona XtraDB Cluster Initial Setup
========

.. contents:: 
   :backlinks: entry
   :local:

Setup Steps
-------------

TL;DR
~~~~~

#. `Download and install Virtualbox`_: http://virtualbox.org
#. `Download and install Vagrant`_: http://vagrantup.com
#. `Load the base vagrant box into your Vagrant environment`_: ``vagrant box add pxc-tutorial-preloaded http://bit.ly/pxc-tutorial-preloaded-box``
#. `Get a copy of this repository`_: ``git clone https://github.com/jayjanssen/percona-xtradb-cluster-tutorial.git``
#. `vagrant up`_:: ``cd percona-xtradb-cluster-tutorial; vagrant up``
#. Review the ``00-Tutorial-Process`` document about how to work through this tutorial.


Download and install Virtualbox
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Download Virtualbox from `here <https://www.virtualbox.org/wiki/Downloads>`_.

Virtualbox can run virtual machines on your laptop and supports Linux, Mac, and Windows (and is free).


Download and install Vagrant
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Download Vagrant from `here <http://vagrantup.com>`_.

Virtualbox uses guest additions software to provide a bridge for file sharing (and other tasks) between the Host and the Guest.  These are required to work for Puppet provisioning to complete.    You can keep your virtual box guest additions updated automatically by running::

	host> vagrant gem install vagrant-vbguest

This will check and auto-update the guest additions whenever you boot your guest VMs. 

Vagrant knows how to setup and manipulate a set of VirtualBox VMs using something called a *VagrantFile*, which is somewhat analogous to a *MakeFile*.


Load the base vagrant box into your Vagrant environment
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you are in a conference tutorial, there is a very good chance that this is available on a USB stick from the instructor::

	vagrant box add pxc-tutorial-preloaded /path/to/usb/stick/pxc-tutorial-preloaded.box

Otherwise, download the preloaded box like this::

	vagrant box add pxc-tutorial-preloaded http://bit.ly/pxc-tutorial-preloaded-box

Note that most/all of the required software for setting up the PXC cluster is included already on this box. 

This tutorial environment can also be built using a bare CentOS box, but the provisioning will take longer as all the RPM packages will need to be downloaded via Yum.  This is automatically done, but can make building the environment much slower (and impossible at a Conference).

Vagrant uses *boxes* for baseline OS installs to build on.  This step downloads a CentOS 6.3 minimal image and names it as the box `centos6`.  *VagrantFiles* can refer to this box when they want to build a VM.


Get a copy of this repository
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you are in a conference tutorial, there is a very good change this repository is available on a USB stick from the instructor::

	cp -av /path/to/usb/stick/percona-xtradb-cluster-tutorial .

You can also fetch this from github over the internet::

	host> git clone https://github.com/jayjanssen/percona-xtradb-cluster-tutorial.git

If you don't have git, you can simply download a copy of this repository in `the compressed format of your choice here <https://github.com/jayjanssen/percona-xtradb-cluster-tutorial/downloads>`_.

You will need a local copy of all the code and configuration in this git repository on your local machine.  If you don't have/like git, you can download it a full tarball/zip file from github.


vagrant up
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

::
	cd percona-xtradb-cluster-tutorial
	vagrant up

Sometimes some race conditions creep into the provisioning in the ``vagrant up`` causing errors, in such cases it's generally safe to either re-run ``vagrant up`` or ``vagrant provision``.

*If ``vagrant up`` doesn't work, be sure you are in the root directory of this repository and you see a Vagrantfile!*

``vagrant up`` sets up all the cluster nodes and PXC according to the rules found in the VagrantFile (and subsequent Puppet configuration).  

**If all went correctly, you should now have a working 3 node PXC cluster.**


Problems with the setup
-----------------------

There are occasions where the ``vagrant up`` command can generate some errors and not fully complete.  All examples of this I have seen tend to be recoverable by trying a few workaround steps until the nodes are up and the provisioning (i.e. puppet) completes successfully.  Sometimes it's helpful to try the following commands only on the specific node having the issue.  The nodes are named ``node1``, ``node2``, ``node3`` and you can add them to the end of most (all?) vagrant commands to work only on that specific node.  

- If the node appears to boot, but Puppet fails, try rerunning ``vagrant provision``
- If the node appears to boot, but you can't ssh to it and it appears hung, first try ``vagrant halt <nodename>`` and if that doesn't work ``vagrant halt -f <nodename>``
- With VirtualBox 4.2, I got it to work by running (for each node) ``vagrant up <nodename>; vagrant halt <nodename>; vagrant up <nodename>``
- If you are still stuck, be sure you have the most recent version of this git repository and try again.
- If you can't solve it, please `open an issue <https://github.com/jayjanssen/percona-xtradb-cluster-tutorial/issues>`_ with the details of your environment (OS, Vagrant and Virtualbox versions).


Can my machine handle this?
---------------------------

Valid question.  

- Currently the Vagrant file downloads a single CentOS base box that is around 300MB.  
- It creates 3 individual Virtual machines that each use 256M of RAM.  
- Unpacked and fully installed, each machine takes ~1.3G of disk space.  
- These are 64-bit VMs, with a single virtual CPU each.  They will not run on a 32-bit host OS, sorry.
- I have taken steps to try to minimize the CPU utilization during the modules, but there might be some cases where it gets somewhat high during some of the experiments.  