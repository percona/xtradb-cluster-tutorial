Application to Cluster High Availablity 
======================

.. contents:: 
   :backlinks: entry
   :local:

HAProxy
----------

Installing HAproxy
~~~~~~~~~~~~~~~~~~~

Haproxy is available in the base Centos 6.4+ repos::

	yum install haproxy


Setting and testing up Clustercheck
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

First of all, we need to setup a health check for HAProxy to use on each node.  PXC comes with a built in health check called 'clustercheck'.  Let's run this on our command line in node1 now::

	[root@node1 ~]# clustercheck
	HTTP/1.1 503 Service Unavailable
	Content-Type: text/plain

	Percona XtraDB Cluster Node is not synced.

This says our node is down, but is it?  Clustercheck is a shell script, look at ``/usr/bin/clustercheck`` in a text editor to see what it does.

- How does it connect to MySQL?
- What does it actually check? (`Hint <http://www.codership.com/wiki/doku.php?id=galera_node_fsm>`_)
- What do you need to do to make it work?  For the purposes of this tutorial, try to do it without modifying the clustercheck script, though enabling the ERR_FILE variable may help.

**Check if clustercheck works, diagnose, and fix**

After you fix it, it should start working::

	[root@node1 ~]# clustercheck
	HTTP/1.1 200 OK
	Content-Type: text/plain

	Percona XtraDB Cluster Node is synced.
	

This logs into the local mysql instance and checks the cluster status.  It should always return an HTTP result, and if it thinks the node is healthy, it will return a 200 HTTP response.  


Hooking Clustercheck up to a TCP port
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

HAProxy can be configured to poll this on each node, but we need to somehow set this up as a daemon listening on a port for HAProxy to talk to.  For this purpose we use xinetd.  The nuances of xinetd aren't incredibly important here, but note that it will listen on a set of ports and will fork programs to answer incoming TCP requests on those ports on request.  

Add the xinetd configuration for clustercheck by creating/modifying a file called in ``/etc/xinetd.d/mysqlchk`` with these contents::

	# default: on
	# description: mysqlchk
	service mysqlchk
	{
	# this is a config for xinetd, place it in /etc/xinetd.d/
	        disable = no
	        type = UNLISTED
	        flags = REUSE
	        socket_type = stream
	        port = 9200
	        wait = no
	        user = nobody
	        server = /usr/bin/clustercheck
	        log_on_failure += USERID
	        only_from = 192.168.70.0/24
	        # recommended to put the IPs that need
	        # to connect exclusively (security purposes)
	        per_source = UNLIMITED
	}

This creates a listen port on 9200 and will fork a clustercheck for each connection there.  Note that the PXC server package contains a version of this config, but it needs modification out of the box.  

Now, install and start xinetd::

	yum install xinetd
	systemctl restart xinetd

We can check if the service works via curl::

	curl http://192.168.70.2:9200

If you've reached this point, then you have a working health check on node1. Setup the other nodes as well.

**Setup clustercheck to respond on 9200 correctly on all nodes**


Configuring HAProxy for a rotation of all nodes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now that we have working health checks, let's start configuring HAProxy.  For our purposes, we'll only run haproxy on node1.  Let's create a baseline config in /etc/haproxy/haproxy.cfg::

	global
		log 127.0.0.1   local0
		log 127.0.0.1   local1 notice
		maxconn 4096
		uid 99
		gid 99
		daemon
	
	defaults
		log global
		mode tcp
		balance leastconn
		option  httpchk
		option  tcplog
		option  dontlognull
		retries 3
		option redispatch 
		option nolinger
		maxconn 2000
		contimeout 5000
		clitimeout 50000
		srvtimeout 50000
		
	# Stats interface
	listen  lb_stats *:9999
		mode    http
		balance roundrobin
		stats   uri /
		stats   realm "HAProxy Stats"
	

We're not going to go over the options here, check the `HAProxy docs <http://haproxy.1wt.eu/#docs>`_ for more information.  

Now, let's add a port that will load balance across all our nodes for reads by adding these lines to the end of the file we just created::

	listen cluster-reads 0.0.0.0:5306
		default-server on-marked-down shutdown-sessions
		server node1 192.168.70.2:3306 check port 9200 
		server node2 192.168.70.3:3306 check port 9200 
		server node3 192.168.70.4:3306 check port 9200 

This is setting up a port 5306.  It will balance connections to the server with the least number of connections.  It will use HTTP for healthchecking (``httpchk``).  Finally, it will use all three of our nodes as potential targets, and monitor them on port 9200.

Let's startup HAProxy to see if it's working::

	systemctl start haproxy


Now connect through our HAProxy port (5306) and query the ``wsrep_node_name`` to see what node we are connected to::

	[root@node1 ~]# mysql -u test -ptest -h 192.168.70.2 -P 5306 -e "show variables like 'wsrep_node_name';"
	+-----------------+-------+
	| Variable_name   | Value |
	+-----------------+-------+
	| wsrep_node_name | node1 |
	+-----------------+-------+

- What happens when you reconnect?
- How would you configure your application clients to use this load balanced rotation?
- How would you have to setup GRANTs for application users in this case?


Configuring HAProxy for a writer port
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Our reader port is a load-balanced rotation of all nodes.  However, for writes we may not want to send traffic to all the nodes, but only to one to avoid deadlocking errors.  Since PXC has synchronous replication, it's not hard to fail over writes, but we want to ensure that writes only go to a single node at a time, but can also failover automatically if that node goes down.  

Let's add the following config to the ``haproxy.cfg``::

	listen cluster-writes 0.0.0.0:4306
		default-server on-marked-down shutdown-sessions on-marked-up shutdown-backup-sessions
		server node1 192.168.70.2:3306 track cluster-reads/node1
		server node2 192.168.70.3:3306 track cluster-reads/node2 backup
		server node3 192.168.70.4:3306 track cluster-reads/node3 backup

This looks very similar to our previous configuration, except for the port number and the presence of the 'backup' flag.  Restart haproxy and test the connection to see what node you reach::

	[root@node1 ~]# mysql -u test -h 192.168.70.2 -P 4306 -e "show variables like 'wsrep_node_name';"

- How does this look in the HAProxy admin page?
- Where do the connections go if node1 fails?
- What happens to connections already on node2 if node1 recovers?  Is there any way to fix this?


Keepalived
~~~~~~~~~~~

If you don't need load balancing, and just want your application to use a single node in the cluster with failover, then keepalived is a nice solution.  Install keepalived like this on all the nodes::

	yum install keepalived

Now edit the /etc/keepalived/keepalived.conf file and add this::

	vrrp_script chk_pxc {
	        script "/usr/bin/clustercheck"
	        interval 1
	}
	vrrp_instance PXC {
	    state MASTER
	    interface eth1
	    virtual_router_id 51
	    priority 100
	    nopreempt
	    virtual_ipaddress {
	        192.168.70.100
	    }
	    track_script {
	        chk_pxc
	    }
	    notify_master "/bin/echo 'now master' > /tmp/keepalived.state"
	    notify_backup "/bin/echo 'now backup' > /tmp/keepalived.state"
	    notify_fault "/bin/echo 'now fault' > /tmp/keepalived.state"
	}

Now start keepalived on all the nodes::

	systemctl start keepalived
	
And check for which host has the VIP::

	ip addr list | grep 192.168.70.100
	
Verify that we can connect to MySQL through the vip::

	[root@node1 ~]# while( true; ) do mysql -u test -ptest -h 192.168.70.100 -e "show variables like 'wsrep_node_name'";  sleep 1; done

And experiment with shutting down the node that has the vip and watching connections transition to a new node in the cluster.
	