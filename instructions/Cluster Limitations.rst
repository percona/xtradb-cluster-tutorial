Cluster Limitations
======================

.. contents:: 
   :backlinks: entry
   :local:


MyISAM support
--------------

Create a MyISAM table to see if it works::

	node1 mysql> use test;
	node1 mysql> CREATE TABLE `isam` (
	  `i` int(10) unsigned NOT NULL AUTO_INCREMENT,
	  `j` char(32) DEFAULT NULL,
	  PRIMARY KEY (`i`)
	) ENGINE=MyISAM;
	
	node3 mysql> use test; show tables;
	+----------------+
	| Tables_in_test |
	+----------------+
	| isam           |
	| sbtest1        |
	+----------------+
	2 rows in set (0.00 sec)

Our table replicated, so it must work, right?  Now try to insert some rows::

	node1 mysql> insert into isam (j) values ('myisam support off');

* What do we see on node3?

Now try::

	node1 mysql> set global wsrep_replicate_myisam=ON;
	node1 mysql> insert into isam (j) values ('myisam support on');

- Did it replicate to node3?
- Are the tables identical?

Even with MyISAM support enabled, it is replicated with STATEMENT based replication, which breaks wsrep_auto_increment_control.


Non-transactional SQL functions
---------------------------------

Statements that don't modify an Innodb table don't replicate (typically)::

	node1 mysql> select get_lock( 'a', 10 );
	node3 mysql> select get_lock( 'a', 10 );
	
	node1 mysql> flush tables with read lock;
	node3 mysql> flush tables with read lock;

- What would you expect to happen?
- What really happens?

