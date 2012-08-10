Cluster Experimentation
=======================

.. contents:: 
   :backlinks: entry
   :local:

Assumptions
-----------

You have completed the `Progressive Setup <01-Progressive%20Setup.rst>`_ steps successfully and have a working three node cluster.  

If you want to do these steps without successfully setting up the cluster yourself, execute::

	host> vagrant provision

This *should* fix any goofs in your setup and leave you with a cluster in working order.


Reading and Writing to the Cluster
----------------------------------

Now that we have a working 3 node cluster, let's experiment with reading and writing to the cluster.  

It is recommended that you run ``myq_status -t 1 wsrep`` on each node in a terminal window (or windows) that you can easy glance at.  This will show you the status of the cluster at a glance.  

Pick a node (any node) and create a new table in the ``test`` schema::

	node2 mysql> create table autoinc ( i int unsigned not null auto_increment primary key, j varchar(32) );
	Query OK, 0 rows affected (0.02 sec)

	node2 mysql> show create table autoinc\G
	*************************** 1. row ***************************
	       Table: autoinc
	Create Table: CREATE TABLE `autoinc` (
	  `i` int(10) unsigned NOT NULL AUTO_INCREMENT,
	  `j` varchar(32) DEFAULT NULL,
	  PRIMARY KEY (`i`)

Now, let's insert some data into this table::

	node2 mysql> insert into autoinc (j) values ('node2' );
	Query OK, 1 row affected (0.00 sec)

	node2 mysql> insert into autoinc (j) values ('node2' );
	Query OK, 1 row affected (0.01 sec)

	node2 mysql> insert into autoinc (j) values ('node2' );
	Query OK, 1 row affected (0.00 sec)

Now select all the data in the table::

	node2 mysql> select * from autoinc;
	
What strikes you as odd about the rows?


Deadlocks on COMMIT
-------------------

One of the things to be aware of with using PXC is that there can be rollbacks issued by the server on COMMIT, which cannot happen in standard single-node Innodb.

To illustrate this, open a mysql session on two nodes and follow these steps carefully::

	node1 mysql> set autocommit=off;
	Query OK, 0 rows affected (0.00 sec)

	node1 mysql> show variables like 'autocommit';
	+---------------+-------+
	| Variable_name | Value |
	+---------------+-------+
	| autocommit    | OFF   |
	+---------------+-------+
	1 row in set (0.00 sec)
	
	node1 mysql> select * from autoinc;
	+---+-------+
	| i | j     |
	+---+-------+
	| 1 | node2 |
	| 4 | node2 |
	| 7 | node2 |
	+---+-------+
	3 rows in set (0.00 sec)

	node1 mysql> update autoinc set j="node1" where i = 1;
	Query OK, 1 row affected (0.00 sec)
	Rows matched: 1  Changed: 1  Warnings: 0
	
We now have an open transaction on node1 with a lock on a single row.  If we run ``SHOW ENGINE INNODB STATUS\G``, we can see the transaction open with a record lock::

	------------
	TRANSACTIONS
	------------
	...
	---TRANSACTION 83B, ACTIVE 50 sec
	2 lock struct(s), heap size 376, 1 row lock(s), undo log entries 1
	MySQL thread id 3972, OS thread handle 0x7fddb84e0700, query id 16408 localhost root sleeping
	show engine innodb status
	Trx read view will not see trx with id >= 83C, sees < 83C
	TABLE LOCK table `test`.`autoinc` trx id 83B lock mode IX
	RECORD LOCKS space id 0 page no 823 n bits 72 index `PRIMARY` of table `test`.`autoinc` trx id 83B lock_mode X locks rec but not gap


While the transaction is still open, go try to modify the row on another node::

	node3 mysql> set autocommit=off;
	Query OK, 0 rows affected (0.00 sec)

	node3 mysql> show variables like 'autocommit';
	+---------------+-------+
	| Variable_name | Value |
	+---------------+-------+
	| autocommit    | OFF   |
	+---------------+-------+
	1 row in set (0.00 sec)

	node3 mysql> select * from autoinc;
	+---+-------+
	| i | j     |
	+---+-------+
	| 1 | node2 |
	| 4 | node2 |
	| 7 | node2 |
	+---+-------+
	3 rows in set (0.00 sec)

	node3 mysql> update autoinc set j="node3" where i=1;
	Query OK, 1 row affected (0.01 sec)
	Rows matched: 1  Changed: 1  Warnings: 0

	node3 mysql> commit;
	Query OK, 0 rows affected (0.00 sec)
	
	node3 mysql> select * from autoinc;
	+---+-------+
	| i | j     |
	+---+-------+
	| 1 | node3 |
	| 4 | node2 |
	| 7 | node2 |
	+---+-------+
	3 rows in set (0.00 sec)
	
This commit succeeded!  On standard Innodb, this should have blocked waiting for the row lock to be released by the first transaction.  Let's go back and see what happens if we try to commit on node1::

	node1 mysql> commit;
	ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction

	node1 mysql> select * from autoinc;
	+---+-------+
	| i | j     |
	+---+-------+
	| 1 | node3 |
	| 4 | node2 |
	| 7 | node2 |
	+---+-------+
	3 rows in set (0.00 sec)

We get a deadlock on node1, in spite of it being the first transaction to open a record lock.  What has happened here?

To compare this behavior with standalone Innodb, redo these steps but with two separate sessions on the same node and see what happens.  


Restarting cluster nodes
------------------------

Let's experiment with how cluster nodes leave and join the cluster.  Pick one node and execute ``service mysql stop`` and ``service mysql start``.  Observe ``myq_status -t 1 wsrep`` on the remaining nodes and see how shutting down and restarting the node affects them.


SST and the Donor node
-----------------------

Finding the Donor node
~~~~~~~~~~~~~~~~~~~~~~

When an state transfer is required, an existing cluster node is selected to be the *Donor*.  A backup is taken of this node to copy to the node requiring the state transfer.  We already saw this when bringing up our nodes.  However, let's see the behavior of the donor node.  

On node3, baseline the node and restart mysql so an SST happens::

	[root@node3 ~]# baseline.sh 
	Shutting down MySQL (Percona Server).... SUCCESS! 
	...
	[root@node3 ~]# cp /etc/my.cnf.cheater /etc/my.cnf
	[root@node3 ~]# service mysql start
	Starting MySQL (Percona Server).................................................. SUCCESS!


While the server was restarting, check ``myq_status`` to see who is the donor::

	Wsrep    Cluster         Node                 Flow        Replicated      Received
	    time stat conf size   rdy  cmt  ctd dist  paus sent   que  ops size   que  ops size
	18:22:13 Prim   17    3    ON Dono   ON    0     0    0     0    0    0     0  1.0 58.0
	
Notice the ``Node cmt`` is ``Dono`` or *Donor*.  

Forcing a Donor
~~~~~~~~~~~~~~~

Let's force one of our nodes to be the donor always so we can perform some tests on it.  Add the following line to the my.cnf of node3::

	[mysqld]
	...
	wsrep_sst_donor=node2

In this case node2 will always be selected to be the donor (assuming it is alive).


Reads and writes on the Donor with xtrabackup SST
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

node2 is our dedicated Donor node, so let's start some regular writes there so we can see how it behaves during Donation.  On node2, setup and start `pt-heartbeat <http://www.percona.com/doc/percona-toolkit/pt-heartbeat.html>`_ so a row gets updated every second from there.  Due to a limitation of pt-heartbeat, we must create a legacy version of the heartbeat table that will work with PXC::

	node2 mysql> create schema percona;
	Query OK, 1 row affected (0.00 sec)

	node2 mysql> use percona;
	Database changed
	node2 mysql> CREATE TABLE heartbeat (
	    ->   id int NOT NULL PRIMARY KEY,
	    ->   ts datetime NOT NULL
	    -> );
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

Now, re-baseline node3 and restart an SST.  Watch the heartbeat monitor on node1 and myq_status on node2 carefully.  What do you observe?  Any idea why?

Bonus points:
	Modify /usr/bin/wsrep_sst_xtrabackup on node2 add ``--no-lock`` to ``INNOBACKUPEX_ARGS``::

	INNOBACKUPEX_ARGS="--no-lock"

How does that change the behavior?  When is that safe to run?


Reads and writes on the Donor with rsync SST
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Let's see how rsync SST is different from Xtrabackup.  Back on node3, change the SST method::

	wsrep_sst_method=rsync

and reset and restart mysql here.  What differences do you note compared with xtrabackup SST?

If you have time, feel free to try other SST methods.  All the possible options are easy to find::

	[root@node2 ~]# rpm -ql Percona-XtraDB-Cluster-server | grep wsrep_sst

- Which method is the fastest?
- Will that hold true as the database grows?
- Which method causes the least interference with cluster operations?

