State Snapshot Transfer (SST) and the Donor node
======================

.. contents:: 
   :backlinks: entry
   :local:

Finding the Donor node
----------------------

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

- Which node became the donor for node3?
- Is this always the same?

Forcing a Donor
---------------

Baseline node3 again as above, and let's force one of our nodes to be the donor always so we can perform some tests on it.  Add the following line to the my.cnf of node3::

	[mysqld]
	...
	wsrep_sst_donor=node2

In this case node2 will always be selected to be the donor.

- What happens if node2 is down when node3 is started?
- When would this be useful?


Reads and writes on the Donor with xtrabackup SST
-------------------------------------------------

Follow the ``Running pt-heartbeat`` section of the ``00-Initial Setup`` document.  You should have a terminal open with pt-heartbeat running showing you any delay in the heartbeat when you are done.

Now, re-baseline node3 and restart an SST.  Carefully watch the heartbeat monitor on node1 and myq_status on node2 carefully.  

- What happens to the heartbeat before the SST is done?
- What do you see in the ``myq_status`` output at the same time?
- Any idea why?

**Bonus points**: Modify /usr/bin/wsrep_sst_xtrabackup on node2 add ``--no-lock`` to ``INNOBACKUPEX_ARGS``::

	INNOBACKUPEX_ARGS="--no-lock"

*NOTE*: this may not work in 5.5.27 due to a `bug <https://bugs.launchpad.net/percona-xtradb-cluster/+bug/1047886>`_.

- How does that change the behavior?  
- When is that safe to run?


Reads and writes on the Donor with rsync SST
--------------------------------------------

Let's see how rsync SST is different from Xtrabackup.  Back on node3, change the SST method::

	wsrep_sst_method=rsync

and reset and restart mysql here.  What differences do you note compared with xtrabackup SST?

If you have time, feel free to try other SST methods.  All the possible options are easy to find::

	[root@node2 ~]# rpm -ql Percona-XtraDB-Cluster-server | grep wsrep_sst

- Which method is the fastest?
- Will that hold true as the database grows?
- Which method causes the least interference with cluster operations?


Broken replication
--------------------

Let's simulate a case where one node gets out of sync with the others.  With node3 back up and running, let's make the heartbeat table inconsistent::

	node3 mysql> set global wsrep_on='OFF';                                                                       
	node3 mysql> delete from heartbeat;

You should see something like this in node3's error log::

	120908 17:44:16 [ERROR] Slave SQL: Could not execute Update_rows event on table percona.heartbeat; Can't find record in 'heartbeat', Error_code: 1032; handler error HA_ERR_KEY_NOT_FOUND; the event's master log FIRST, end
	_log_pos 108, Error_code: 1032
	120908 17:44:16 [Warning] WSREP: RBR event 2 Update_rows apply warning: 120, 1320
	120908 17:44:16 [ERROR] WSREP: Failed to apply trx: source: 12e18919-f9c8-11e1-0800-a54166ff94af version: 2 local: 0 state: APPLYING flags: 1 conn_id: 1024 trx_id: 6223 seqnos (l: 237, g: 1320, s: 1319, d: 1319, ts: 1347119056001170054)120908 17:44:16 [ERROR] WSREP: Failed to apply app buffer: <D0>gKP^S, seqno: 1320, status: WSREP_FATAL
	         at galera/src/replicator_smm.cpp:apply_wscoll():49
	         at galera/src/replicator_smm.cpp:apply_trx_ws():120120908 17:44:16 [ERROR] WSREP: Node consistency compromized, aborting...

- What happens to node3?
- How does the cluster fix this problem?
- When will this problem be detected?
- What is the advantage of this approach?