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

	[root@node1 ~]# 	sysbench --test=sysbench_tests/db/oltp.lua \
	--mysql-host=node1 --mysql-user=test --mysql-db=test \
	--oltp-table-size=250000 --report-interval=1 --max-requests=0 \
	--tx-rate=10 run | grep tps

Let's use node3 as the node we take in and out of the cluster with some kind of simulated failure.

I highly recommend you run ``myq_status -t 1 wsrep`` on each node in a separate window or set of windows so you can monitor the state of each node at a glance as we run our tests.

After each of the following steps, be sure mysqld is up and running on all nodes, and all 3 nodes belong to the cluster.


Manually SSTing a node with Xtrabackup
---------------------------------------

It is possible to use an existing Xtrabackup to start a new node without SST IF the backup is not very old.  Let's simulate that condition by doing an xtrabackup on node3 while it is running::

	[root@node3 ~]# mkdir backup
	[root@node3 ~]# innobackupex --galera-info backup

- What affect does the backup have on sysbench?

This does an xtrabackup and it collects the galera state by taking a FLUSH TABLES WITH READ LOCK.  We can avoid that in certain cases, but we'll cover that in the next section.

Now, stop mysql on node3 and prepare to restart the node with the backup::

	[root@node3 ~]# service mysql stop
	[root@node3 ~]# innobackupex --apply-log ./backup/2013-02-25_14-30-45/

Your backup will have a different timestamp.  Now remove the existing datadir and copy over the backup::

	[root@node3 ~]# rm -rf /var/lib/mysql
	[root@node3 ~]# cp -av ./backup/2013-02-25_14-30-45 /var/lib/mysql
	[root@node3 ~]# chown -R mysql.mysql /var/lib/mysql

Now, we have a datadir ready to restart, but we need the galera GTID.  This will be contained in a file in our backup directory::

	[root@node3 ~]# cat /var/lib/mysql/xtrabackup_galera_info 
	8797f811-7f73-11e2-0800-8b513b3819c1:22809

Now, we need to initialize the grastate.dat (carefully) from that information::

	[root@node3 ~]# vi /var/lib/mysql/grastate.dat
	[root@node3 ~]# chown -R mysql.mysql /var/lib/mysql/grastate.dat
	[root@node3 ~]# cat /var/lib/mysql/grastate.dat 
	# GALERA saved state
	version: 2.1
	uuid:    8797f811-7f73-11e2-0800-8b513b3819c1
	seqno:   22809
	cert_index:
		

Now, we are ready to try starting mysql::

	[root@node3 ~]# service mysql start

If all goes well, node3 will start with only an IST.  If not, you may need to try the whole process again.  


Wsrep Recovery
---------------

The Galera GTID can also be recovered directly from a process similar to an Innodb recovery on a crashed node.  When a node crashes the grastate.dat is not synchronized, so this is often an alternative to re-SSTing the entire node again.

Kill mysql on node3 again and attempt to collect the saved GTID with wsrep_recover::

	[root@node3 ~]# ps axf
	....
	24986 pts/0    S      0:00 /bin/sh /usr/bin/mysqld_safe --datadir=/var/lib/mysql --pid-file=/var/lib/mysql
	25280 pts/0    Sl     0:02  \_ /usr/sbin/mysqld --basedir=/usr --datadir=/var/lib/mysql --plugin-dir=/usr/
	
	[root@node3 ~]# kill -9 24986; kill -9 25280
	
	[root@node3 ~]# mysqld_safe --wsrep_recover
	130225 14:47:41 mysqld_safe Logging to '/var/lib/mysql/error.log'.
	130225 14:47:41 mysqld_safe Starting mysqld daemon with databases from /var/lib/mysql
	130225 14:47:41 mysqld_safe WSREP: Running position recovery with --log_error=/tmp/tmp.x0ISIPa5Qa
	nohup: ignoring input and appending output to `nohup.out'
	130225 14:47:46 mysqld_safe WSREP: Recovered position 8797f811-7f73-11e2-0800-8b513b3819c1:32552
	130225 14:47:51 mysqld_safe mysqld from pid file /var/lib/mysql/node3.pid ended

This tells us our recovered GTID, so we tell Galera to start there when it starts up::

	[root@node3 ~]# service mysql start --wsrep_start_position=8797f811-7f73-11e2-0800-8b513b3819c1:32552  

- Does this work properly?  Any issues?
- Try --wsrep_start_position with the xtrabackup recovery?  Does it work?
- This position is recovered from the Innodb redo log.  Are there any circumstances where it would not work?


Cases where node state is reset
--------------------------------

We have already seen that a mysql crash (simulated with kill -9) will not save the proper seqno in the grastate.dat.  However the state is reset in a few other cases. Let's check a few.

Bad Configuration
~~~~~~~~~~~~~~~~~~

Add a single line to your my.cnf in the [mysqld] section::

	foo

Now, stop mysql, check the state of your grastate, try to restart, and check again::

	[root@node3 ~]# service mysql stop
	[root@node3 ~]# cat /var/lib/mysql/grastate.dat
	[root@node3 ~]# service mysql start
	[root@node3 ~]# cat /var/lib/mysql/grastate.dat

- What happened to the state?  Why?

**Do this experiment to see what happens.  Recover the node grastate using the wsrep_recover position above as before**

* Any issues with --wsrep_start_position?
* 

Node out of sync
~~~~~~~~~~~~~~~~~~~

When a node crashes because it out of sync, it also triggers the same situation::

	[root@node3 ~]# cat /var/lib/mysql/grastate.dat 
	[root@node3 ~]# mysql test
   node3 mysql> set wsrep_on=OFF;
	node3 mysql> delete from sbtest1 limit 10000;  # repeat until node3 crashes
	[root@node3 ~]# cat /var/lib/mysql/grastate.dat 

- What error do you see in node3's log?  What triggered the crash?
- What happened to the saved state?  Why?  Is this right or wrong?
- What's the right way to recover if this happened in production?


Extra Credit
--------------

- Build a node from a non-locking Xtrabackup.  How can you instruct Xtrabackup not to take the FTWRL.  How do you extract the Galera GTID?  What are the limitations of this method?