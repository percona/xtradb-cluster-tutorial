Online Schema Changes
======================

.. contents:: 
   :backlinks: entry
   :local:

Setting up Live Environment
--------------------------

To simulate a live environment, we will kick off setup and kickoff a sysbench oltp test with a single test thread.

First, let's prepare a test table::

	[root@node1 ~]# sysbench --test=sysbench_tests/db/common.lua --mysql-user=root --mysql-db=test --oltp-table-size=100000 prepare

Now, we can start a test run::

	[root@node1 ~]# sysbench --test=sysbench_tests/db/oltp.lua --mysql-user=root --mysql-db=test --oltp-table-size=100000 --report-interval=1 --max-requests=0 run
	WARNING: Both max-requests and max-time are 0, running endless test
	sysbench 0.5:  multi-threaded system evaluation benchmark
	
	Running the test with following options:
	Number of threads: 1
	Report intermediate results every 1 second(s)
	Random number generator seed is 0 and will be ignored
	
	
	Threads started!
	
	[   1s] threads: 1, tps: 83.06, reads/s: 1173.80, writes/s: 332.23, response time: 20.27ms (95%)
	[   2s] threads: 1, tps: 77.98, reads/s: 1094.73, writes/s: 315.92, response time: 20.71ms (95%)
	[   3s] threads: 1, tps: 82.01, reads/s: 1148.20, writes/s: 328.06, response time: 20.23ms (95%)
	[   4s] threads: 1, tps: 78.99, reads/s: 1105.88, writes/s: 315.97, response time: 18.94ms (95%)
	[   5s] threads: 1, tps: 76.01, reads/s: 1054.19, writes/s: 300.05, response time: 20.48ms (95%)
	[   6s] threads: 1, tps: 87.00, reads/s: 1213.93, writes/s: 347.98, response time: 18.18ms (95%)
	...

Your performance may vary.  As the WARNING message indicates, this test will go forever until you ``Ctrl-C`` it.  You can kill and restart this test at any time

Note that if you mess something up, you can cleanup the test table and start these steps over if needed::

	[root@node1 ~]# sysbench --test=sysbench_tests/db/common.lua --mysql-user=root --mysql-db=test --oltp-table-size=100000 cleanup
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

Galera provides a `Rolling Schema Upgrade <http://www.codership.com/wiki/doku.php?id=rolling_schema_upgrade>` setting to allow you to avoid globally locking the cluster on a schema change.  Let's try it out, set this global variable on all three nodes::

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

This is not a tutorial on `pt-online-schema-change <http://www.percona.com/doc/percona-toolkit/2.1/pt-online-schema-change.html>`, but let's illustrate that it works with PXC.

First, set the ``wsrep_OSU_method`` back to TOI (the default) on all nodes::

	node1 mysql> set global wsrep_OSU_method='TOI';
	node2 mysql> set global wsrep_OSU_method='TOI';
	node3 mysql> set global wsrep_OSU_method='TOI';

Now, let's do our schema change fully non-blocking::

	[root@node2 ~]# pt-online-schema-change --alter "add column z varchar(32)" D=test,t=sbtest1 --chunk-size=100 --execute

Note that I only set --chunk-size because your VMs are likely running at full-capacity, so giving pt-online-schema-change full rein will affect your application performance negatively.  

- How does the application respond to this change?
- If you remove the --chunk-size option, how does it respond?  Why?
