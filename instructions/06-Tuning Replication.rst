Monitoring and Tuning Replication
==============

.. contents:: 
   :backlinks: entry
   :local:


Setup
----------

We will run our application workload on node1::

	[root@node1 ~]# run_sysbench_oltp.sh

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


Wsrep Sync Wait 
-----------------------

Transactions might be queued up when we go to read from another node, so to guarantee a consistent read we can set wsrep_sync_wait = 1.

	node3 mysql> set global wsrep_sync_wait=1;	
	[root@node3 ~]# time mysql -e "select * from test.sbtest1 limit 1"

The select should work normally, but now take the read lock in another terminal and see what the select does if you run it again.

- What does the select do while the queue is blocked?
- What does the same query do with wsrep_causal_reads turned off when the queue is full?
- wsrep_sync_wait is a bitmask from 1-7.  Check the PXC manual for what the different values mean.


Taking backups
---------------

Backups commonly use FLUSH TABLES WITH READ LOCK, but as we see above, this can cause flow control on the cluster.  We need a way to backup a node without causing flow control.  

The safe way to take a backup on a PXC node is to manually put the node into the Donor/Desync state::

	node3 mysql> set global wsrep_desync=ON;

You should see myq_status report the node in the 'Dono' or 'Donor/Desynced' state. 

	node3 mysql> FLUSH TABLES WITH READ LOCK;

NOW if you run the backup, you may still see a brief period where the FTWRL is locking node3, but a node in the Desync state will NOT send flow control to the cluster if it gets lagged.  

 It will remain in this state until wsrep_desync is turned off::

	node3 mysql> set global wsrep_desync=OFF;
 
Note that with Backup locks introduced in PXC 5.6.21, using wsrep_desync for this may no longer be necessary.


Measuring maximum replication throughput
---------------------------------------------

We can also use the wsrep_desync trick to measure how fast a given node can apply transactions.  If we desync the node, lock tables and let the recv queue build up on the node, and then suddenly release it, we can see the highest apply rate the node can handle::

	node3 mysql> set global wsrep_desync=ON;
	node3 mysql> flush tables with read lock;
	

Now we let replication fall way behind.  Once the recv queue ('Queue Dn' in myq_status) is sufficiently high, release the lock and watch the 'Ops Dn' column to see how high the apply rate gets::

	node3 mysql> unlock tables;

This is a measurement of how fast a given node can apply (at least in a burst).  This number compared with the current apply rate can start to give you some impression of how much throughput your cluster can sustain.

	node3 mysql> set global wsrep_desync=OFF;


