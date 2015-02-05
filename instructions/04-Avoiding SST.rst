Avoiding SST
==============

.. contents:: 
   :backlinks: entry
   :local:


Intro
--------
The purpose of this module is to illustrate precisely how a node uses/recovers its state relative to the cluster, precisely how SST works, and how to avoid SST in certain conditions when it is not necessary.  These tips should help you avoid SST in production when it can be very painful (especially on a large dataset with only a few production nodes).  

A refresher on IST
------------------

Remember a node can be restarted without SST if:

* The node remembers its state
* All writesets since that state are contained on the gcache of another node


Setup
----------

We will run our application workload on node1::

	[root@node1 ~]# run_sysbench_oltp.sh

Let's use node3 as the node we take in and out of the cluster with some kind of simulated failure.

I highly recommend you run ``myq_status wsrep`` on each node in a separate window or set of windows so you can monitor the state of each node at a glance as we run our tests.

After each of the following steps, be sure mysqld is up and running on all nodes, and all 3 nodes belong to the cluster.


Manually SSTing a node with Xtrabackup
---------------------------------------

It is possible to use an existing Xtrabackup to start a new node without SST IF the backup is not very old.  Let's simulate that condition by doing an xtrabackup on node3 while it is running::

	[root@node3 ~]# mkdir backup
	[root@node3 ~]# innobackupex --galera-info backup

Now, stop mysql on node3 and prepare to restart the node with the backup::

	[root@node3 ~]# systemctl stop mysql
	[root@node3 ~]# innobackupex --apply-log ./backup/2015-02-04_19-50-28/

Your backup will have a different timestamp.  Now remove the existing datadir and copy over the backup::

	[root@node3 ~]# rm -rf /var/lib/mysql/*
	[root@node3 ~]# innobackupex --copy-back ./backup/2015-02-04_19-50-28/
	[root@node3 ~]# chown -R mysql.mysql /var/lib/mysql

Now, we have a datadir ready to restart, but we need the galera GTID.  This will be contained in a file in our backup directory::

	[root@node3 ~]# cat /var/lib/mysql/xtrabackup_galera_info 
	7c12c42a-a23d-11e4-a88f-064c92c75b61:661886
	
Now, we need to initialize the grastate.dat (carefully) from that information::

	[root@node3 ~]# vi /var/lib/mysql/grastate.dat
	[root@node3 ~]# chown -R mysql.mysql /var/lib/mysql/grastate.dat
	[root@node3 ~]# cat /var/lib/mysql/grastate.dat 
	# GALERA saved state
	version: 2.1
	uuid:    7c12c42a-a23d-11e4-a88f-064c92c75b61
	seqno:   661886
	cert_index:
		

Now, we are ready to try starting mysql::

	[root@node3 ~]# systemctl start mysql

If all goes well, node3 will start with only an IST.  If not, you may need to try the whole process again.  


Wsrep Recovery
---------------

The Galera GTID can also be recovered directly from a process similar to an Innodb recovery on a crashed node.  When a node crashes the grastate.dat is not synchronized, so this is often an alternative to re-SSTing the entire node again.

Kill mysql on node3 again and attempt to collect the saved GTID with wsrep_recover::

	[root@node3 ~]# killall -9 mysqld
	
	[root@node3 ~]# mysqld_safe --wsrep_recover
	140311 20:18:35 mysqld_safe Logging to '/var/lib/mysql/error.log'.
	140311 20:18:35 mysqld_safe Starting mysqld daemon with databases from /var/lib/mysql
	140311 20:18:35 mysqld_safe WSREP: Running position recovery with --log_error='/var/lib/mysql/wsrep_recovery.mlGjrI' --pid-file='/var/lib/mysql/node3-recover.pid'
	140311 20:18:44 mysqld_safe WSREP: Recovered position 266407b9-93eb-11e3-8417-76ef50d50f84:138532
	140311 20:18:49 mysqld_safe mysqld from pid file /var/lib/mysql/node3.pid ended

This tells us our recovered GTID, so we tell Galera to start there when it starts up by editing the grastate.dat manually like we did above.

However, because we killed mysqld directly and it didn't get a chance to abort or exit cleaning, the grastate.dat is in a state that looks like this::

	# GALERA saved state
	version: 2.1
	uuid:    7c12c42a-a23d-11e4-a88f-064c92c75b61
	seqno:   -1
	cert_index:

When that is the case, we can simply restart mysql and --wsrep_recovery will be run automatically to recover the node.  

	[root@node3 ~]# systemctl start mysql

- Does this work properly and IST?  Any issues?
- This position is recovered from the Innodb redo log.  Are there any circumstances where it would not work?


Cases where node state is reset
--------------------------------

We have already seen that a mysql crash (simulated with kill -9) will not save the proper seqno in the grastate.dat.  However the state is reset in a few other cases. Let's check a few.

Bad Configuration
~~~~~~~~~~~~~~~~~~

Add a single line to your my.cnf in the [mysqld] section::

	foo

Now, stop mysql, check the state of your grastate, try to restart, and check again::

	[root@node3 ~]# systemctl stop mysql
	[root@node3 ~]# cat /var/lib/mysql/grastate.dat
	[root@node3 ~]# systemctl start mysql
	[root@node3 ~]# cat /var/lib/mysql/grastate.dat

- What happened to the state?  Why?

**Do this experiment to see what happens.  Recover the node grastate using the wsrep_recover position above as before**



Node out of sync
~~~~~~~~~~~~~~~~~~~

When a node crashes because it out of sync, it also triggers the same situation::

	[root@node3 ~]# cat /var/lib/mysql/grastate.dat 
	[root@node3 ~]# mysql test
	ps axf
	node3 mysql> set wsrep_on=OFF;
	node3 mysql> delete from test.sbtest1 limit 10000;  # repeat until node3 crashes
	[root@node3 ~]# cat /var/lib/mysql/grastate.dat 

- What error do you see in node3's log?  What triggered the crash?
- What happened to the saved state?  Why?  Is this right or wrong?
- What's the right way to recover if this happened in production?
