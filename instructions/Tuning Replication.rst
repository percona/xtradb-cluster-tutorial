Monitoring and Tuning Replication
==============

.. contents:: 
   :backlinks: entry
   :local:


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


Observing replication lag
---------------------------

Watch ``myq_status`` carefully on all nodes.  On node3, connect to mysql and run::

	node3 mysql> flush tables with read lock;

This will block replication on node3 and you will see how the cluster behaves when a node gets slow.

- What happens to the sysbench tps?
- How big does the inbound queue get on node3?
- When does flow control kick in?  Which node is sending it?
- What is the effect of flow control on the queues on node1?

To release the lock, execute::

	node3 mysql> unlock tables;



Tuning Flow Control
---------------------

Adjust the ``gcs.fc_limit`` setting in wsrep_provider_options and repeat the above test::

	node3 mysql> set global wsrep_provider_options="gcs.fc_limit=500";

Wait until flow control kicks in and note the size of the local receive queue.  You can use myq_status, or you may need to check the ``wsrep_local_recv_queue`` status variable on node3 directly::

	node3 mysql> show global status like 'wsrep_local_recv_queue';

- At what point does flow control check in?  How does the application perform up to that point?
- Unlock the tables and watch the flow control messages.  When does flow control turn off?

Change the ``gcs.fc_factor`` setting.  It defaults to 1.0 (the max), but can be set anywhere between 0.0 and 1.0::

node3 mysql> set global wsrep_provider_options="gcs.fc_factor=0.5";

Now, re-lock the tables and wait until flow control kicks in.  Release the table locks and observe at what point flow control turns off.

- How does flow control change with a smaller fc_factor?
- When might this be useful?
- Try fc_factor=0.0.  When might this be useful?

**Set fc_factor=1.0 before continuing**

The other setting relevant to tuning flow control is 'fc_master_slave', which is not a dynamic variable.  Add this to the my.cnf on node3 and restart mysql::

	wsrep_provider_options          = "gcs.fc_master_slave=YES"

- How big does node3's replication queue have to get before flow control kicks in now?



Multiple Applier Threads
--------------------------

You may want to adjust the tx-rate on sysbench to allow the replication queue to grow faster for this experiment.  Set fc_limit on node3 much higher and lock the tables until the queue is full::

	node3 mysql> set global wsrep_provider_options="gcs.fc_limit=5000";

Unlock the tables and time how long it takes until node3's queue is empty.  

- What is the time limit?
- What is wsrep_cert_deps_distance on node3? (dst column in myq_status)

We have wsrep_slave_threads=2 in our default configuration.  Compare the amount of time for node3 to catchup with 2 slave threads vs 10 slave threads.  Unfortunately, while wsrep_slave_threads allows you to change it's value dynamically, it really has no effect unless you restart the server.  Modify wsrep_slave_threads in node3's my.cnf::

	wsrep_slave_threads             = <new val>

- Which value catches up faster?  2 slave threads or 10?
- Compare the rate of 'Ops Dn' from myq_status -- what does this tell you about the rate at which node3 is processing transactions?


Wsrep Causal Reads 
-----------------------

Transactions might be queued up when we go to read from another node, so to guarantee a consistent read we can enable wsrep_causal_reads.

	node3 mysql> set session wsrep_causal_reads=1;
	node3 mysql> select * from test.sbtest1 limit 1\G

The select should work normally, but now take the read lock in another terminal and see what the select does if you run it again.

- What does the select do while the queue is blocked?
- What does the same query do with wsrep_causal_reads turned off when the queue is full?

