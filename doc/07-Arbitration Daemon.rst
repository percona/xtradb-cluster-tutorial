Using the Galera Arbitration Daemon (garbd)
======================

.. contents:: 
   :backlinks: entry
   :local:

Introduction to Garbd
----------------------

The Galera Arbitration Daemon is meant to be a lightweight daemon that will function as a voting member of a PXC cluster, but without needing to run a full mysqld or store a full state copy of the data.  Do note, however, that all replication traffic for the cluster does pass through garbd.  

``garbd`` can be found in the PXC server package.

- Under what circumstances should you run garbd?
- Where should garbd be placed in your network relative to your other nodes?


Before we start, startup ``myq_status`` on one (or many) node(s) to watch the cluster state::

	[root@node1 ~]# myq_status -t 1 wsrep
	Wsrep    Cluster         Node                 Flow        Replicated      Received
	    time stat conf size   rdy  cmt  ctd dist  paus sent   que  ops size   que  ops size
	22:41:20 Prim    7    3    ON Sync   ON    0     0    0     0    0    0     0  2.0  237
	22:41:21 Prim    7    3    ON Sync   ON    0     0    0     0    0    0     0    0    0
	22:41:22 Prim    7    3    ON Sync   ON    0     0    0     0    0    0     0    0    0
	22:41:23 Prim    7    3    ON Sync   ON    0     0    0     0    0    0     0    0    0
	22:41:24 Prim    7    3    ON Sync   ON    0     0    0     0    0    0     0    0    0

Also, startup the ``quick_update.pl`` script as described in the ``Monitoring commit latency`` section of the ``00-Tutorial-Process`` document so you can see the effect on application writes when the below happens.  

Two node cluster without arbitration
------------------------------------

Shut down mysql on node2, leaving node1 and node3 as the sole members of the cluster::

	[root@node2 ~]# service mysql stop

Now, shutdown node3, leaving only node1::

	[root@node3 ~]# service mysql stop
	Shutting down MySQL (Percona Server)........ SUCCESS!

- What happens?

node1 remains up because node3 gracefully exited the cluster.  Bring node3 back up and simulate a network failure between node1 and node3::

	[root@node3 ~]# service mysql start
	Starting MySQL (Percona Server)..... SUCCESS!
	[root@node3 ~]# iptables -A INPUT -s 192.168.70.2 -j DROP; iptables -A OUTPUT -s 192.168.70.2 -j DROP; 

- What (eventually) happens?  How long does it take?  Why?
- What is the status of wsrep on both node1 and node3?
- What happens if you try to do something on node1 or node3? (Try selecting a table or using a database).  
- Can you write on either node?
- What would the result be if your application were allowed to write to either node in this state?

You can recover node3 by stopping iptables::

	[root@node3 ~]# service iptables stop


Replacing a node with garbd
---------------------------

So we've learned that an ungraceful failure in a two node cluster leaves the cluster in an inoperable state.  This is by design and to prevent split brain network partitions from ruining your day.  Since this is a very undesirable thing to happen, it's best if we can run a 3rd node, but what if we only have budget for two beefy PXC nodes?

In such a case, we turn to ``garbd``.  Let's startup garbd on node2::

	[root@node2 ~]# garbd --help

We have to invoke ``garbd`` from the command line, there are no init scripts yet.  We need to give it one of the existing nodes to connect to, and the name of the cluster::

	[root@node2 ~]# garbd -a gcomm://192.168.70.2 -g trimethylxanthine

- Does the output from garbd remind you of anything?
- How many nodes are in the cluster now?

Now that we have 3 nodes, we can simulate node3 going down (network loss to both nodes)::

	[root@node3 ~]# iptables -A INPUT -s 192.168.70.2 -j DROP; \
	iptables -A INPUT -s 192.168.70.3 -j DROP; iptables -A OUTPUT -s 192.168.70.2 -j DROP; \
	iptables -A OUTPUT -s 192.168.70.3 -j DROP

- What (eventually) happens?  Why?  How long does it take?
- What is the advantage of using garbd in this case?

Again, recover node3 by stopping iptables::

	[root@node3 ~]# service iptables stop


Replication through garbd
---------------------------

One of the features of garbd that isn't obvious is that it can act as a replication relay in case the a direct network link is down between two of your normal nodes.  Let's test it out by using iptables rules to simulate a partial network breakage.  First, setup a heartbeat running on node1, and a monitor for it on node3 using the information in the ``00-Tutorial-Process`` document::

	[root@node1 ~]# pt-heartbeat --update --database percona
	[root@node3 ~]# pt-heartbeat --monitor --database percona

You should see a 0 delay on node3 from the heartbeats coming from node1.

Now, let's simulate a network issue from node1 to node3::

	[root@node3 ~]# iptables -A INPUT -s 192.168.70.2 -j DROP; iptables -A OUTPUT -s 192.168.70.2 -j DROP; 

- Does the heartbeat continue?
- Does it cause any delay?
