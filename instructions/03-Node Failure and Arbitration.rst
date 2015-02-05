Node Failure and Arbitration
===============================

.. contents:: 
   :backlinks: entry
   :local:

Node Failure
-------------------

Setup
~~~~~~~~~~~~~~~~~~~

We will run our application workload on node1::

	[root@node1 ~]# run_sysbench_oltp.sh

Let's use node3 as the node we take in and out of the cluster with some kind of simulated failure.

I highly recommend you run ``myq_status wsrep`` on each node in a separate window or set of windows so you can monitor the state of each node at a glance as we run our tests.

After each of the following steps, be sure mysqld is up and running on all nodes, and all 3 nodes belong to the cluster.


Latency incurred by a node stop/start
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

What does explicitly starting and stopping nodes in our cluster do to our write clients?  Let's see::

	[root@node3 ~]# date; systemctl restart mysql

**Restart mysql on node3 and observe how the cluster and the application reacts**

- What is the observed effect on writes?  
- Are those results consistent? (Feel free to try this repeatedly)


Partial network failure
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

As an experiment, let's see what happens if node3 only looses connectivity to node1 (and not to node2)::

	[root@node3 ~]# date; iptables -A INPUT -s node1 -j DROP; iptables -A OUTPUT -s node1 -j DROP

*Prevent any network communication to node3 from node1

- Does node3 stay in the cluster?
- What effect does this have on writes?
- How is replication working in this case?

When you are ready to allow node3 to communicate with the other nodes, simply stop the iptables service::

	[root@node3 ~]# iptables -F

**Make sure to restore communications to and from all nodes before going to the next step!!**


Total network failure
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A graceful node mysqld shutdown should behave differently from a node that simply stops responding on the network by dropping all packets on node3 to and from the other nodes::

	[root@node3 ~]# date; iptables -A INPUT -s node1 -j DROP; iptables -A INPUT -s node2 -j DROP; iptables -A OUTPUT -s node1 -j DROP; iptables -A OUTPUT -s node2 -j DROP

**Block all traffic from the other nodes into node3**

- What is the observed effect on write latency?
- What happens to node3's state?
- Can you do anything on node3?

Now, restore connectivity::

	[root@node3 ~]# iptables -F

**Drop iptables again on node3**

- What happens when the node can talk to the cluster again?
- Does this action have any noticeable effect on write latency?
- What does node3's log say about how it re-synced with the cluster?

**Make sure to restore communications to and from all nodes before going to the next step!!**


Using the Galera Arbitration Daemon (garbd)
---------------------------------------------

.. contents:: 
   :backlinks: entry
   :local:

Introduction to Garbd
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Galera Arbitration Daemon is meant to be a lightweight daemon that will function as a voting member of a PXC cluster, but without needing to run a full mysqld or store a full state copy of the data.  Do note, however, that all replication traffic for the cluster does pass through garbd.  

``garbd`` can be found in the PXC galera.  It is unnecessary to install the full server to get garbd.

- Under what circumstances should you run garbd?
- Where should garbd be placed in your network relative to your other nodes?


Two node cluster without arbitration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Shut down mysql on node2, leaving node1 and node3 as the sole members of the cluster::

	[root@node2 ~]# systemctl stop mysql

**Shutdown node2**

- What happens?

Simulate a network failure between node1 and node3::

	[root@node3 ~]# date; iptables -A INPUT -s node1 -j DROP; iptables -A OUTPUT -s node1 -j DROP

**Simulate a network failure on node3**

- What (eventually) happens?  How long does it take?  Why?
- What is the status of wsrep on both node1 and node3?
- What happens if you try to do something on node1 or node3? (Try selecting a table or using a database).  
- Can you write on either node?
- What would the result be if your application were allowed to write to either node in this state?

You can recover node3 by stopping iptables::

	[root@node3 ~]# iptables -F

**Drop the iptables rules on node3**


Replacing a node with garbd
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

So we've learned that an ungraceful failure in a two node cluster leaves the cluster in an inoperable state.  This is by design and to prevent split brain network partitions from ruining your day.  Since this is a very undesirable thing to happen, it's best if we can run a 3rd node, but what if we only have budget for two beefy PXC nodes?

In such a case, we turn to ``garbd``.  Let's install and startup garbd on node2::

	[root@node2 ~]# yum install Percona-XtraDB-Cluster-garbd-3.x86_64
	[root@node2 ~]# garbd --help

We have to invoke ``garbd`` from the command line, there are no init scripts yet.  We need to give it one of the existing nodes to connect to, and the name of the cluster::

	[root@node2 ~]# garbd -a gcomm://node1:4567,node3:4567 -g mycluster

**Start garbd on node2**

- Does the output from garbd remind you of anything?
- How many nodes are in the cluster now?

Now that we have 3 nodes, we can simulate node3 going down (network loss to both nodes)::

	[root@node3 ~]# date; iptables -A INPUT -s node1 -j DROP; iptables -A INPUT -s node2 -j DROP; iptables -A OUTPUT -s node1 -j DROP; iptables -A OUTPUT -s node2 -j DROP
	
**Completely isolate node3 from the other two nodes**

- What (eventually) happens?  Why?  How long does it take?
- What is the advantage of using garbd in this case?

Again, recover node3 by stopping iptables::

	[root@node3 ~]# iptables -F

**Recover node3**

Replication through garbd
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now, let's simulate a network issue from node1 to node3::

	[root@node3 ~]# date; iptables -A INPUT -s node1 -j DROP; iptables -A OUTPUT -s node1 -j DROP

**Isolate node3 only from node1**

- Does replication continue?
- Does it cause any delay?


Extra Credit
--------------

Tuning to optimize node failure detection
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Read Codership's `node failure documentation <http://www.codership.com/wiki/doku.php?id=node_failure>`_.  There are a series of tuning variables that adjust how the cluster reacts when nodes stop responding suddenly.  These variables (according to the doc) are::

	evs.keepalive_period <= evs.inactive_check_period <= evs.suspect_timeout <= evs.inactive_timeout <= evs.consensus_timeout

Here are the default variables as I see them as they would be configured in the my.cnf::

	wsrep_provider_options = "evs.keepalive_period=PT1S;evs.inactive_check_period=PT0.5S;evs.suspect_timeout=PT5S;evs.inactive_timeout=PT15S;evs.consensus_timeout=PT30S"

We can see that the default settings don't appear to follow the rules from the documentation.  However, let's see what we can do to retune the cluster.  Based the above documentation and the `galera provider options <http://www.codership.com/wiki/doku.php?id=galera_parameters_0.8>`_, make a guess about what should be tuned and see how it affects write latencies.  Some notes:

- Setting bad values here can either cause mysqld to crash on restart, or (occasionally) spew helpful error messages into the mysql error log
- You must put the settings in the my.cnf on each node and restart.
- Try setting only a subset of variables. 
- Try making only very incremental changes.
- You have to change the setting on all the nodes separately, there is no way to apply a setting to all nodes in the cluster at once.
- Block all network traffic to node3 as in the previous step to simulate the outage.
- Messing with these variables can really screw up your cluster requiring you to re-SST all your nodes.  Have fun!

Questions:

- What timeout setting ended up being most effective?
- What are the tradeoffs of how you retuned the settings compared with the defaults? 
