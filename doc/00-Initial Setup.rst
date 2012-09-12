Percona XtraDB Cluster Initial Setup
========

.. contents:: 
   :backlinks: entry
   :local:

How to work through this Tutorial
----------------------------------

The basic steps are as follows:

#. Setup your environment (see below)
#. Familiarize yourself with how to use vagrant (i.e., ssh to nodes, etc.)
#. Pick a module and work through it.  Typically it's best to start with the ``01-Progressive Setup`` module, but generally you can work through any module in any order
#. After you finish each module, be sure to shutdown any test processes you may have running, and you may want to run ``vagrant provision`` again to restore the cluster back to original working order.

Setting up your Environment
--------------------------

TL;DR
~~~~~~~

It's a **very** good idea to do these steps *before* the tutorial session because conference WiFi tends to be unreliable at best.  At a minimum, at least do up through the step to download the centos6 box, which is several hundred MB.

#. Download and install Virtualbox from `here <https://www.virtualbox.org/wiki/Downloads>`_. (Current version: 4.1.22)
#. Download and install Vagrant from `here <http://vagrantup.com>`_.  Current version: 1.0.3
#. Keep your virtual box guest additions updated automatically: ``host> vagrant gem install vagrant-vbguest``
#. Download centos6 vagrant box: (310MB) (optional, `vagrant up` will do this automatically): ``vagrant box add centos6 https://dl.dropbox.com/u/7225008/Vagrant/CentOS-6.3-x86_64-minimal.box``
#. Get a copy of this git repository: ``host> git clone https://github.com/jayjanssen/pxc-tutorial``
#. Run ``vagrant up``::

	cd pxc-tutorial
	vagrant up
	
That should do it!  Sometimes some race conditions creep into the provisioning in the ``vagrant up`` causing errors, in such cases it's generally safe to either re-run ``vagrant up`` or ``vagrant provision``.

If you have any problems beyond this, please open an issue in this github repository with the details.


What does this actually do?
~~~~~~~~~~~~~~~~~~~~~~~~~~~

The basic flow of what's happening above is:

#. Downloading virtualbox -- this can run virtual machines on your laptop and supports Linux, Mac, and Windows (and is free).
#. Installing the Vagrant tool -- This tool knows how to setup and manipulate a set of VirtualBox VMs using something called a *VagrantFile*, which is somewhat analogous to a *MakeFile*.
#. Virtualbox VMs use tools installed on the GuestOS to do things like share folders with the host machine (i.e., your laptop).  This step allows Vagrant to keep those tools up to date with whatever version of VirtualBox you have.
#. Vagrant uses *boxes* for baseline OS installs to build on.  This step downloads a CentOS 6.3 minimal image and names it as the box `centos6`.  *VagrantFiles* can refer to this box when they want to build a VM.
#. You will need a local copy of all the code and configuration in this git repository on your local machine.  If you don't have/like git, you can download it a full tarball/zip file from github.
#. `vagrant up` sets up all the cluster nodes and PXC according to the rules found in the VagrantFile (and subsequent Puppet configuration).  If all goes correctly, you should have a working 3 node PXC cluster.


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

- Each node is running a primary IP on the 192.168.70.0/24 subnet.  For the purposes of these exercises, this is the network for all client connections as well as cluster replication and any other tasks.

- Virtualbox *might* crash your laptop every once in a while.  If you don't like it, ask Oracle for your money back.

- Running the command ``baseline.sh`` on any node will do the following:

  - Stop mysqld
  - Remove /etc/my.cnf
  - Wipe out the existing /var/lib/mysql and create a clean datadir.

- If a node gets into a weird state, try doing the ``baseline.sh`` trick on it and then::

	host> vagrant provision <node>

- You can remove the cluster state on a node without affecting the data on that node by removing::
	/var/lib/mysql/grastate.dat

- Sometimes init.d loses track of a mysqld instance.  If you can't shutdown mysqld with ``service mysql stop``, try ``mysqladmin shutdown``.  If that doesn't work, try ``killall mysqld_safe; killall mysqld``


Terms and conventions
---------------------

PXC
	Percona XtraDB Cluster. http://www.percona.com/doc/percona-xtradb-cluster/index.html

Galera
	The technology on which PXC is based.  PXC is basically Galera + Percona Server.  See http://codership.com for more info.

wsrep
	Short for 'Work-Set Replicator'.  You'll see this referred to in mysql settings (SHOW VARIABLES and SHOW STATUS) to for Galera items.

VirtualBox
	Oracle's Free Virtual Machine tool (analogous to VMware).  http://www.virtualbox.org
	
Vagrant
	Tool to manage and configure VMs according to a standard recipe.  http://vagrantup.com

`host>` 
	means your laptop from the root directory of the git repository
	
screen#
	Often the walkthrough instructions assume you have multiple windows or screens open so you can watch multiple things at once.  This can be a physically separate terminal window, or a unix `screen` window if you are comfortable with it.  Note that `screen` is preinstalled on the nodes for your convenience.


Ways to test the Cluster
------------------------

Running pt-heartbeat
~~~~~~~~~~~~~~~~~~~~

I use pt-heartbeat in my PXC testing to show when there are replication hiccups and delays.  Due to a limitation of pt-heartbeat, we must create a legacy version of the heartbeat table that will work with PXC::

	node2 mysql> create schema percona;
	Query OK, 1 row affected (0.00 sec)

	node2 mysql> CREATE TABLE percona.heartbeat (
	    id int NOT NULL PRIMARY KEY,
	    ts datetime NOT NULL
	    );
	Query OK, 0 rows affected (0.01 sec)
	
Now, start pt-heartbeat on node2::

	[root@node2 ~]# pt-heartbeat --update --database percona
	
One node1, let's monitor the heartbeat::

	[root@node1 ~]# pt-heartbeat --monitor --database percona
	   0s [  0.00s,  0.00s,  0.00s ]
	   0s [  0.00s,  0.00s,  0.00s ]
	   0s [  0.00s,  0.00s,  0.00s ]
	   0s [  0.00s,  0.00s,  0.00s ]
	   0s [  0.00s,  0.00s,  0.00s ]
	   0s [  0.00s,  0.00s,  0.00s ]
	   0s [  0.00s,  0.00s,  0.00s ]
	   0s [  0.00s,  0.00s,  0.00s ]

This output will show us if there are any delays in the heartbeat compared with the current time.  


Monitoring commit latency
~~~~~~~~~~~~~~~~~~~~~~~~~~

To illustrate high client write latency, I have created a script called ``quick_update.pl``, which should be in your path.  This script does the following:
	- Runs the same UPDATE command that pt-heartbeat does, though with only 10ms of sleep between each execution. It updates and prints a counter on each execution. 
	- If it detects any of the UPDATEs took more than 50ms (this is configurable if you edit the script), then it prints 'slow', the date timestamp, and the final query latency is printed (in seconds) when the query does finish.  

If you haven't done so yet, create the ``percona`` schema and the ``heartbeat`` table as per the last section::  

	node2 mysql> create schema percona;
	use percona;
	CREATE TABLE heartbeat (
		id int NOT NULL PRIMARY KEY,
		ts datetime NOT NULL
	);
	insert into heartbeat (id, ts) values (1, NOW());
	
The execution looks something like::

	[root@node1 ~]# quick_update.pl 
	9886
	slow: Wed Aug 15 15:01:19 CEST 2012 0.139s
	10428

Note that occasionally the writes to the 3 node cluster setup on VMs on your laptop might be sporadically slow. This can be taken as noise.  


Using sysbench to generate load
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To simulate a live environment, we will kick off setup and kickoff a sysbench oltp test with a single test thread.

**Prepare the test table**

	[root@node1 ~]# sysbench --test=sysbench_tests/db/common.lua --mysql-user=root --mysql-db=test --oltp-table-size=250000 prepare


**Start a Test run**

	[root@node1 ~]# sysbench --test=sysbench_tests/db/oltp.lua --mysql-user=root --mysql-db=test --oltp-table-size=250000 --report-interval=1 --max-requests=0 --tx-rate=10 run | grep tps
	[   1s] threads: 1, tps: 11.00, reads/s: 154.06, writes/s: 44.02, response time: 41.91ms (95%)
	[   2s] threads: 1, tps: 18.00, reads/s: 252.03, writes/s: 72.01, response time: 24.02ms (95%)
	[   3s] threads: 1, tps: 9.00, reads/s: 126.01, writes/s: 36.00, response time: 20.74ms (95%)
	[   4s] threads: 1, tps: 13.00, reads/s: 181.97, writes/s: 51.99, response time: 19.19ms (95%)
	[   5s] threads: 1, tps: 13.00, reads/s: 182.00, writes/s: 52.00, response time: 22.75ms (95%)
	[   6s] threads: 1, tps: 10.00, reads/s: 140.00, writes/s: 40.00, response time: 22.35ms (95%)
	[   7s] threads: 1, tps: 13.00, reads/s: 181.99, writes/s: 52.00, response time: 21.09ms (95%)
	[   8s] threads: 1, tps: 13.00, reads/s: 181.99, writes/s: 52.00, response time: 23.71ms (95%)

Your performance may vary.  Note we are setting ``--tx-rate`` as a way to prevent your VMs from working too hard.  Feel free to adjust ``-tx-rate`` accordingly, but be sure that you have several operations a second for the following tests.  

As the WARNING message indicates, this test will go forever until you ``Ctrl-C`` it.  You can kill and restart this test at any time

**Cleanup test table**

Note that if you mess something up, you can cleanup the test table and start these steps over if needed::

	[root@node1 ~]# sysbench --test=sysbench_tests/db/common.lua --mysql-user=root --mysql-db=test cleanup
	sysbench 0.5:  multi-threaded system evaluation benchmark

	Dropping table 'sbtest1'...

