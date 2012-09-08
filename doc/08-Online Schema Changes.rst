Online Schema Changes
======================

.. contents:: 
   :backlinks: entry
   :local:

Test setup
---------------

Follow the ``Using sysbench to generate load`` section of the ``Initial Setup`` document to prepare a test table and start a sysbench test run.  Keep the terminal running the test visible on your screen.  


Basic Alter Table
-------------------

Now that we have a basic workload running, let's see the effect of altering that table.  In another window, run an ALTER TABLE on test.sbtest1::

	node1 mysql> alter table test.sbtest1 add column `m` varchar(32);
	Query OK, 102006 rows affected (4.24 sec)
	Records: 102006  Duplicates: 0  Warnings: 0

- How is our application affected by this change? (i.e., What happens to the tps that sysbench is reporting?)


Now, let's go to node2 and do a similar operation::

	node2 mysql> alter table test.sbtest1 add column `n` varchar(32);
	Query OK, 103471 rows affected (4.11 sec)
	Records: 103471  Duplicates: 0  Warnings: 0

- Does running the command from another node make a difference?


Create a copy of our test table with data from the original table::

	node2 mysql> create table test.foo like test.sbtest1;
	Query OK, 0 rows affected (0.06 sec)
	
	node2 mysql> insert into test.foo select * from test.sbtest1;
	Query OK, 106376 rows affected (20.10 sec)
	Records: 106376  Duplicates: 0  Warnings: 0

Note that this *will* stop sysbench for a time (Do you know why?).  Now let's run the ALTER on this new table::

	node2 mysql> alter table test.foo add column `o` varchar(32);

- How long does the alter take?
- How long is sysbench blocked for?  Why?


Rolling Schema Upgrades
-----------------------

Galera provides a `Rolling Schema Upgrade <http://www.codership.com/wiki/doku.php?id=rolling_schema_upgrade>`_ setting to allow you to avoid globally locking the cluster on a schema change.  Let's try it out, set this global variable on all three nodes::

	node1 mysql> set global wsrep_OSU_method='RSU';
	node2 mysql> set global wsrep_OSU_method='RSU';
	node3 mysql> set global wsrep_OSU_method='RSU';


Add another column to ``test.foo`` (the table that sysbench is *not* modifying)::

	node2 mysql> alter table test.foo add column `p` varchar(32);

- What is the effect on our live workload?


Add a column on ``test.sbtest``, but on node2::

	node2 mysql> alter table test.sbtest1 add column `q` varchar(32);

- What is the effect on our live workload?
- How do we need to propagate this change around our cluster?  How can we do it without stopping our application?

Finally, let's drop a column on ``test.sbtest1`` that sysbench is using (you may want to watch myq_status while you do this)::

	node2 mysql> alter table test.sbtest1 drop column `c`;

- What happened?
- How did it affect the application workload?
- Why did it happen?
- What is the limitation of using the Rolling Schema Upgrade feature?


pt-online-schema-change
-----------------------

This is not a tutorial on `pt-online-schema-change <http://www.percona.com/doc/percona-toolkit/2.1/pt-online-schema-change.html>`_, but let's illustrate that it works with PXC.

First, set the ``wsrep_OSU_method`` back to TOI (the default) on all nodes::

	node1 mysql> set global wsrep_OSU_method='TOI';
	node2 mysql> set global wsrep_OSU_method='TOI';
	node3 mysql> set global wsrep_OSU_method='TOI';

Now, let's do our schema change fully non-blocking::

	[root@node2 ~]# pt-online-schema-change --alter "add column z varchar(32)" D=test,t=sbtest1 --execute

- How does the application respond to this change?
