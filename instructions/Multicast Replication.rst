Multicast Replication 
======================

.. contents:: 
   :backlinks: entry
   :local:


Introduction
--------------------------

Galera by default uses standard TCP unicast packets.  Because every node effectively broadcasts every replication event to every other node, this can dramatically increase the required bandwidth for replication as the number of nodes you have in your cluster increases.

Multicast solves this by using a broadcast address that all members of the cluster listen to.  Hence each message is sent once to the broadcast instead of to each individual unicast IP in turn.  Note that Multi-cast is network-dependent and your network must be configured to allow it and that packets sent to it will be delivered to all nodes.  


Setting up Multicast routing
------------------------------

Because our Virtual Machines have two interfaces, and we are using the second (eth1), we need to instruct our boxes to route traffic to the multicast address space over eth1 explicitly::

	# ip ro add dev eth1 224.0.0.0/4
	# ip ro show | grep 224
	224.0.0.0/4 dev eth1  scope link

244.0.0.0/4 is the standard private multi-cast address space and this rule says to use eth1 to send it.

*Note that this configuration may or may not be necessary in your environment to get this to work*


Configuring Galera
---------------------

Now we simply need to pick an address in this space to use and configure Galera::

	wsrep_provider_options          = "gmcast.mcast_addr=239.192.0.11"

Note that we change nothing else in the configuration.  Unicast is still used by wsrep_cluster_address to find a functioning cluster node address, you can't put a multicast address there (in my testing).  

Like enabling SSL, there is no way to enable this in a rolling fashion throughout the cluster, so you must shutdown every node, enable the config, and restart (bootstrapping the first node)::

	[root@node3 mysql]# service mysql stop
	[root@node2 mysql]# service mysql stop
	[root@node1 mysql]# service mysql stop

Check the grastate.dat on each node, be sure they all have the same state UUID and a positive seqno::

	[root@node3 mysql]# cat grastate.dat
	# GALERA saved state
	version: 2.1
	uuid:    772f377f-9ae7-11e2-0800-f2a92b988574
	seqno:   1
	cert_index:

Start the cluster again (bootstrap the first node) with the Multicast configuration in place.  There should be no need for SST::

	[root@node1 mysql]# service mysql start --wsrep_cluster_address=gcomm://
	[root@node2 mysql]# service mysql start
	[root@node3 mysql]# service mysql start


Other Multicast Settings
-----------------------------------------

- gmcast.mcast_ttl	

http://www.codership.com/wiki/doku.php?id=galera_parameters_0.8
