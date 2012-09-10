Two Node Clusters
==================

.. contents:: 
   :backlinks: entry
   :local:

Why a Two node cluster?
----------------------
Two node clusters are definitely **not** recommended with PXC; you should at least use the Galera Arbitration Daemon (garbd) instead.  

However, there are some cases where it is necessary and useful, and there are other cases where you have lost a node and must operate with reduced redundancy in the cluster.  In such cases, it's handy to know how to manage the cluster when one of your nodes fails.

This information can also be handy for clusters spread evenly across two colocations, two switches, and just about two anything, in the case where one *thing* fails.  

**In that case, the cluster will stop responding to clients and it's important to understand how to get whatever is remaining up and working**

Caveats
-------

The biggest caveat in any setup with *two* of something instead of *three* (or any odd number) is the ability for a split brain (however unlikely) to make it so each remaining fragment of the cluster is *not* have quorum.  Quorum is >= 51% of the cluster nodes, so 1 out of 2, or 2 out of 4 is not enough for Quorum.

If you run in this mode, it is possible to ignore SB prevention and Quorum detection, but this is highly unrecommended.  If you **must** run in this manner, it'd be much better for a failure to take down the cluster, and for a human being to manually bootstrap the cluster fragment they want to continue operation than for two cluster fragments to **DIVERGE**.


Setup of a two node cluster and inducing a node failure
------------------------------------------------------------

To test this, we must first create a condition where there is one cluster node without Quorum.  We cannot simply shutdown 2 nodes, because graceful node shutdown informs the cluster to take the shutting down node out of the Quorum calculation.  

Let's go to a two node cluster between node1 and node3 by shutting down node2::

	[root@node2 ~]# service mysql stop
	Shutting down MySQL (Percona XtraDB Cluster).... SUCCESS!

We should see the cluster drop down to 2 nodes in ``myq_status``::

	[root@node1 ~]# myq_status -t 1 wsrep
	Wsrep    Cluster         Node                 Flow        Replicated      Received
	    time stat conf size   rdy  cmt  ctd dist  paus sent   que  ops size   que  ops size
	21:33:12 Prim   11    3    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:33:13 Prim   11    3    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:33:14 Prim   11    3    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:33:15 Prim   12    2    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  1.0  174
	21:33:16 Prim   12    2    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:33:17 Prim   12    2    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0

Now that we have a two node cluster, let's simulate a failure on node3::

	[root@node3 ~]#  iptables -A INPUT -s 192.168.70.2 -j DROP; iptables -A INPUT -s 192.168.70.3 -j DROP; iptables -A OUTPUT -s 192.168.70.2 -j DROP; iptables -A OUTPUT -s 192.168.70.3 -j DROP 

We should see node1 drop to ``non-PRIMARY``::

	Wsrep    Cluster         Node                 Flow        Replicated      Received
	    time stat conf size   rdy  cmt  ctd dist  paus sent   que  ops size   que  ops size
	21:36:00 non- 1844    1   OFF Init   ON  0.0  0.00    0     0 34.0 6.5K     0 25.0 3.0K
	21:36:01 non- 1844    1   OFF Init   ON  0.0  0.00    0     0  0.0    0     0  0.0    0

We should also see regular database operations fail on node1::

	node1 mysql> select * from percona.heartbeat;
	ERROR 1047 (08S01): Unknown command

We can "recover" node3 by simply disabling firewall rules::

	[root@node3 ~]# service iptables stop                                                      
	iptables: Flushing firewall rules:                         [  OK  ]                        
	iptables: Setting chains to policy ACCEPT: filter          [  OK  ]                        
	iptables: Unloading modules:                               [  OK  ]


At this point, we should see the cluster recover naturally::

	21:36:02 non- 1844    1   OFF Init   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:36:03 non- 1844    1   OFF Init   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:36:04 non- 1844    1   OFF Init   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:36:05 non- 1844    1   OFF Init   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:36:06 non- 1844    1   OFF Init   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:36:07 Prim   13    2    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  1.0  174
	21:36:08 Prim   13    2    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:36:09 Prim   13    2    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:36:10 Prim   13    2    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:36:11 Prim   13    2    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:36:12 Prim   13    2    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0


Bootstrapping a minority of Cluster nodes
------------------------------------------

So you should be capable of inducing a node failure now.  Do so now, and leave node1 in the non-PRIMARY state.  Imagine it is 2AM and you got woken up to fix this problem, what do you do?

Fortunately, the answer is quite easy.  We tell node1 to bootstrap itself::

	node1 mysql> set global wsrep_provider_options="pc.bootstrap=true";
	Query OK, 0 rows affected (0.00 sec)

As if by magic, the remaining node recovers itself.  

	Wsrep    Cluster         Node                 Flow        Replicated      Received
	    time stat conf size   rdy  cmt  ctd dist  paus sent   que  ops size   que  ops size
	21:43:32 non- 1844    1   OFF Init   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:43:33 non- 1844    1   OFF Init   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:43:34 non- 1844    1   OFF Init   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:43:35 non- 1844    1   OFF Init   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:43:36 non- 1844    1   OFF Init   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:43:37 Prim   16    1    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  1.0  119
	21:43:38 Prim   16    1    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:43:39 Prim   16    1    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:43:40 Prim   16    1    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0

And we can do work on node1::

	node1 mysql> select * from percona.heartbeat;
	+----+---------------------+
	| id | ts                  |
	+----+---------------------+
	|  1 | 2012-09-10 20:58:33 |
	+----+---------------------+

- What happens if node3's network issue is fixed?
- Operationally, is it necessary to know node3's state before you bootstrap node1?

*NOTE* the bootstrap is not a setting per-se, it only seems to *reset* the quorum state once.  The setting itself does not show up in SHOW VARIABLES and does not persist.

**NOTE** Be sure both nodes are talking to each other before continuing.


Ignoring Quorum on one Node
-----------------------------

It's possible to tell Galera to ignore the quorum calculation in the case of node failure.  Let's see what happens with that enabled.

	node1 mysql> set global wsrep_provider_options="pc.ignore_quorum=true"; 
	Query OK, 0 rows affected (0.00 sec)

Now "fail" node3.

You should see the following in ``myq_status`` on node1::


	Wsrep    Cluster         Node                 Flow        Replicated      Received
	    time stat conf size   rdy  cmt  ctd dist  paus sent   que  ops size   que  ops size
	21:53:47 Prim   17    2    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:53:48 Prim   17    2    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:53:49 Prim   17    2    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:53:50 Prim   17    2    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:53:51 Prim   18    1    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  1.0  119
	21:53:52 Prim   18    1    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:53:54 Prim   18    1    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0
	21:53:55 Prim   18    1    ON Sync   ON  0.0  0.00    0     0  0.0    0     0  0.0    0

The cluster dropped to a 1 node cluster on node1, and still handles traffic (no bootstrapping required)::

	node1 mysql> select * from percona.heartbeat;
	+----+---------------------+
	| id | ts                  |
	+----+---------------------+
	|  1 | 2012-09-10 20:58:33 |
	+----+---------------------+
	1 row in set (0.00 sec)

- What is the state of node3?
- What does node3's log say?
- Does it make a difference if the iptables traffic is dropped on node1 instead of node3?  (Hint: block 192.168.70.4 from incoming and outgoing traffic on node1 )
- Why is node3 chosen for non-Primary?
- What is the apparent difference between this and manually setting the ``pc.bootstrap`` option?
- Operationally, does this hold advantages over the manual bootstrap setting?  Are there any disadvantages?

**NOTE** Be sure both nodes are talking to each other before continuing.


Ignoring Quorum on both nodes
-----------------------------

Same situation as the last section, but this time, apply the ``ignore_quorum`` setting to both nodes::

	node1 mysql> set global wsrep_provider_options="pc.ignore_quorum=true"; 
	Query OK, 0 rows affected (0.00 sec)
	
	node3 mysql> set global wsrep_provider_options="pc.ignore_quorum=true"; 
	Query OK, 0 rows affected (0.00 sec)

- What is the status of each node?
- Will each node accept MySQL operations?
- Can you write to both nodes?
- What happens to the node status if the network partition gets repaired?
- What do you have to do to get a 2 node cluster back?
- What happens to those writes when the network is repaired?
- Operationally, does running this way have any merit?

**NOTE** Re-enable quorum detection on both nodes.  I found the cleanest way to was to simply restart mysql on each node in turn.


Optional: Ignoring Split Brain 
--------------------------------

Try precisely the same steps in the last two sections, but use pc.ignore_quorum=true instead.   You can also try combining both ignore_sb and ignore_quorum.  

- Do you notice any differences in behavior?
- Any operational advantages here?


Conclusion
------------

In my experiments, I didn't see any obvious difference in behavior in setting ignore_sb and ignore_quorum (I'm looking for more knowledge here).  It would be my advice to *never* use these settings under any circumstances.  

If a two node or two colocation PXC cluster was in use, I would recommend a manual failover option so a *human being* can choose a remaining node (or set of nodes) to bootstrap there to re-enable operations.  This should prevent the other partition from *ever* taking writes until network connectivity is fully restored.

If you want automation in a two node/colo setup, you should use an arbitrator in 3rd node/colocation, that's what it's for.  You *cannot* reliably do automated failover with only two nodes/colos, *unless* you always select a single node/colo to remain "up" on a failure.  