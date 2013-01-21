Essential Topics
=========================================

This module will cover topics crucial to working with PXC.  This section assumes you have completed the 'Migrate Master Slave to Cluster' section.

.. contents:: 
   :backlinks: entry
   :local:


Application Interaction with the Cluster
----------------------------------------

Reading and Writing to the Cluster
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now that we have a working 3 node cluster, let's experiment with reading and writing to the cluster.  

It is recommended that you run ``myq_status -t 1 wsrep`` on each node in a terminal window (or windows) that you can easy glance at.  This will show you the status of the cluster at a glance.  

Pick a node (any node) and create a new table in the ``test`` schema::

	node2 mysql> create table test.autoinc ( i int unsigned not null auto_increment primary key, j varchar(32) );
	Query OK, 0 rows affected (0.02 sec)

	node2 mysql> show create table test.autoinc\G
	*************************** 1. row ***************************
	       Table: autoinc
	Create Table: CREATE TABLE `autoinc` (
	  `i` int(10) unsigned NOT NULL AUTO_INCREMENT,
	  `j` varchar(32) DEFAULT NULL,
	  PRIMARY KEY (`i`)

Now, let's insert some data into this table::

	node2 mysql> insert into test.autoinc (j) values ('node2' );
	Query OK, 1 row affected (0.00 sec)

	node2 mysql> insert into test.autoinc (j) values ('node2' );
	Query OK, 1 row affected (0.01 sec)

	node2 mysql> insert into test.autoinc (j) values ('node2' );
	Query OK, 1 row affected (0.00 sec)

Now select all the data in the table::

	node2 mysql> select * from test.autoinc

**Create the test.autoinc table on node2, insert some rows, and check the data**
	
- Does anything strike you as odd about the rows?
- What happens if you do the inserts on each node in order?

**Experiment with the inserts and pay special attention to the autoincrement column**

- How would the default autoincrement behavior affect your application?

*Information about how to modify this behavior is later in the tutorial* 


Deadlocks when you don't expect them
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

One of the things to be aware of with using PXC is that there can be rollbacks issued by the server on COMMIT (and other unexpected parts of transactions), which cannot happen in standard single-node Innodb.

To illustrate this, open a mysql session on two nodes and follow these steps carefully::

	node1 mysql> set autocommit=off;
	node1 mysql> select * from test.autoinc;
	node1 mysql> update test.autoinc set j="node1" where i = 1;

**NOTE**: you may need to select another row.  Just be sure you always select a row that exists and has a value that your UPDATE will actually *change*.

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

**Open a non-autocommit transaction on node1 and update a row in the test.autoinc table, but do not commit**


While the transaction is still open, go try to modify the row on another node::

	node3 mysql> set autocommit=off;
	node3 mysql> select * from test.autoinc;
	node3 mysql> update test.autoinc set j="node3" where i=1;
	node3 mysql> commit;

**Do the same thing on node3, but set j to a different value, and commit**

- Does the transaction succeed?
- What is the value of that record on node3?  Was it set correctly?

This commit succeeded!  On standard Innodb, this should have blocked waiting for the row lock to be released by the first transaction.  Let's go back and see what happens if we try to commit on node1::

	node1 mysql> commit;

**Commit on node1**

- What happens on node1?
- What is the value of j in the row on node1?

We get a deadlock on node1, in spite of it being the first transaction to open a record lock.  

- Retry these steps, but instead of a ``commit`` on node1, do another select.  What is the result?
- Retry these steps, but instead of two separate nodes, execute them in different sessions on the same node.  What is the result?
- Imagine this is your production environment and you are seeing these deadlocks.  How would you troubleshoot this?
- Does the deadlock show up in ``SHOW ENGINE INNODB STATUS``?

**Experiment further with this behavior until you understand it**




