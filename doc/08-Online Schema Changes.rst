Online Schema Changes
======================

.. contents:: 
   :backlinks: entry
   :local:

Setting up Live Environment
--------------------------

To simulate a live environment, we will kick off setup and kickoff a sysbench oltp test with a single test thread.

First, let's prepare a test table::

	[root@node1 ~]# sysbench --test=sysbench_tests/db/common.lua --mysql-user=root --mysql-db=test --oltp-table-size=250000 prepare

Now, we can start a test run::

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

Note that if you mess something up, you can cleanup the test table and start these steps over if needed::

	[root@node1 ~]# sysbench --test=sysbench_tests/db/common.lua --mysql-user=root --mysql-db=test cleanup
	sysbench 0.5:  multi-threaded system evaluation benchmark

	Dropping table 'sbtest1'...


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
