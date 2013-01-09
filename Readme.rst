Percona XtraDB Cluster Tutorial
================================

This Tutorial to help you walk through various aspects of setting up, migrating to, and using Percona XtraDB Cluster / Galera.

This tutorial was written for Percona employees to give at conferences in either 3 or 6 hours sessions, but should be useful for anyone wanting to explore more about XtraDB Cluster and Galera.

.. contents:: 
   :backlinks: entry
   :local:


How to work through this Tutorial
----------------------------------

**STOP** If you are attending a tutorial, you will receive alternative instructions that do not require you to download anything significant from the Internet.  You can use these instructions to prepare your environment, but it should not be strictly necessary.

The basic flow of working with this tutorial is to setup your environment and then work the module or modules of your choosing documented in the instructions folder.  


Creating the Tutorial Environment (short version)
--------------------------------------------------

This tutorial uses Virtualbox and Vagrant.  Follow these steps to get setup:

#. `Download and install Virtualbox`_: http://virtualbox.org
#. `Download and install Vagrant`_: http://vagrantup.com
#. `Get a copy of this repository`_: ``git clone https://github.com/jayjanssen/percona-xtradb-cluster-tutorial.git``
#. `vagrant up`_:: ``cd percona-xtradb-cluster-tutorial; vagrant up``


**NOTE** During the in-class tutorial, using Vagrant will not strictly be required.  


Creating the Tutorial Environment (Detailed Setup Steps)
-------------

Download and install Virtualbox
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Virtualbox can run virtual machines on your laptop and supports Linux, Mac, and Windows (and is free).

Download Virtualbox from `here <https://www.virtualbox.org/wiki/Downloads>`_.


Download and install Vagrant
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


Vagrant knows how to setup and manipulate a set of VirtualBox VMs using something called a *VagrantFile*, which is somewhat analogous to a *MakeFile*.

Download Vagrant from `here <http://vagrantup.com>`_.

Get a copy of this repository
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you are in a conference tutorial, there is a very good change this repository is available on a USB stick from the instructor::

	cp -av /path/to/usb/stick/percona-xtradb-cluster-tutorial .

You can also fetch this from github over the internet::

	host> git clone https://github.com/jayjanssen/percona-xtradb-cluster-tutorial.git

(Be sure to use the path to the branch of your choosing)

You will need a local copy of all the code and configuration in this git repository on your local machine.  If you don't have/like git, you can download it a full tarball/zip file from github.


vagrant up
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

::
	cd percona-xtradb-cluster-tutorial
	vagrant up

Sometimes some race conditions creep into the provisioning in the ``vagrant up`` causing errors, in such cases it's generally safe to either re-run ``vagrant up`` or ``vagrant provision``.

*If ``vagrant up`` doesn't work, be sure you are in the root directory of this repository and you see a Vagrantfile!*

``vagrant up`` sets up all the cluster nodes and PXC according to the rules found in the VagrantFile (and subsequent Puppet configuration).  

**If all went correctly, you should now have 3 virtual machines ready for tutorial work!**


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

- Currently the Vagrant file downloads a single CentOS base box that is around 300MB.  
- It creates 3 individual Virtual machines that each use 256M of RAM.  
- Unpacked and fully installed, each machine takes ~1.3G of disk space.  
- These are 32-bit VMs, with a single virtual CPU each.
- I have taken steps to try to minimize the CPU utilization during the modules, but there might be some cases where it gets somewhat high during some of the experiments.


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


**NOTE** You can read more at http://docs.vagrantup.com/


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
	Percona XtraDB Cluster. http://www.percona.com/doc/percona-xtradb-cluster

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

::

	[root@node1 ~]# sysbench --test=sysbench_tests/db/common.lua --mysql-user=root --mysql-db=test --oltp-table-size=250000 prepare


**Start a Test run**

::

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



Contributors
---------------------

This repository is free to branch, open issues on, and submit pull requests to.  

I've opened a set of issues for new modules to be written.  If you want to contribute, take the issue, branch the repo, do your changes, and submit a pull request.  I will make an effort now to use branches myself and keep the master branch clean apart from pull merges.

Any review/testing/proofreading you can do would be much appreciated.




