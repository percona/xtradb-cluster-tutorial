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
- Is it necessary to know node3's state before this?


Now