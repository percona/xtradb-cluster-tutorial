Node Failure
======================

.. contents:: 
   :backlinks: entry
   :local:


Monitoring transactional latency
-------------------------------

Node failure causes cluster write latency while the failed/disconnected node is detected.  This is accordance with the CAP Theorem:  that is: you can have 2 of "consistency", "availability", and "partition tolerance", but not 3.  PXC blocking (briefly) on node failure is giving us consistency and partition tolerance at the cost of availability.  

Follow the setup for ``Monitoring commit latency`` in the Initial Setup document.  You should end up with node1 running repeated UPDATE transactions in one terminal window (that you can watch).  


Test nodes
----------

Let's use node1 as the node we run ``quick_update.pl`` from and not take it down.  Let's use node3 as the node we take in and out of the cluster with some kind of simulated failure.  *Keep the terminal with this running visible so you can see when the slow writes hit.*

I highly recommend you run ``myq_status -t 1 wsrep`` on each node in a separate window or set of windows so you can monitor the state of each node at a glance as we run our tests.

After each of the following steps, be sure mysqld is up and running on all nodes, and all 3 nodes belong to the cluster.

Latency incurred by a node stop/start
--------------------------------------

What does explicitly starting and stopping nodes in our cluster do to our write clients?  Let's see::

	[root@node3 ~]# date; service mysql restart

- What is the observed effect on writes?  
- Are those results consistent? (Feel free to try this repeatedly)


Partial network failure
----------------------------

As an experiment, let's see what happens if node3 only looses connectivity to node1 (and not to node2)::

	[root@node3 ~]# date; iptables -A INPUT -s 192.168.70.2 -j DROP; iptables -A OUTPUT -s 192.168.70.2 -j DROP

- Does node3 stay in the cluster?
- What effect does this have on writes?
- How is replication working in this case?

When you are ready to allow node3 to communicate with the other nodes, simply stop the iptables service::

	[root@node3 ~]# service iptables stop
	iptables: Flushing firewall rules:                         [  OK  ]
	iptables: Setting chains to policy ACCEPT: filter          [  OK  ]
	iptables: Unloading modules:                               [  OK  ]

**Make sure to restore communications to and from all nodes before going to the next step!!**


Total network failure
--------------------

A graceful node mysqld shutdown should behave differently from a node that simply stops responding on the network by dropping all packets on node3 to and from the other nodes::

	[root@node3 ~]# date; iptables -A INPUT -s 192.168.70.2 -j DROP; \
	iptables -A INPUT -s 192.168.70.3 -j DROP; iptables -A OUTPUT -s 192.168.70.2 -j DROP; \
	iptables -A OUTPUT -s 192.168.70.3 -j DROP

- What is the observed effect on write latency?
- What happens to node3's state?

Now, restore connectivity:

	[root@node3 ~]# service iptables stop
	iptables: Flushing firewall rules:                         [  OK  ]
	iptables: Setting chains to policy ACCEPT: filter          [  OK  ]
	iptables: Unloading modules:                               [  OK  ]

- What happens when the node can talk to the cluster again?
- Does this action have any noticeable effect on write latency?
- What does node3's log say about how it re-synced with the cluster?

**Make sure to restore communications to and from all nodes before going to the next step!!**


Tuning to optimize node failure detection
-----------------------------------------

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
