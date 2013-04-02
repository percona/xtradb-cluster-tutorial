Setting up HAProxy
======================

.. contents:: 
   :backlinks: entry
   :local:

Resetting node1
--------------------

HAProxy is already installed and configured on node1.  However, let's walkthrough setting it up by first stopping the service and moving the config file::

	[root@node1 ~]# baseline_haproxy.sh


Setting and testing up Clustercheck
-------------------------------------

First of all, we need to setup a health check for HAProxy to use on each node.  PXC comes with a built in health check called 'clustercheck'.  Let's run this on our command line in node1 now::

	[root@node1 ~]# clustercheck
	HTTP/1.1 503 Service Unavailable
	Content-Type: text/plain

	Percona XtraDB Cluster Node is not synced.

This says our node is down, but is it?  Clustercheck is a shell script, look at ``/usr/bin/clustercheck`` in a text editor to see what it does.

- How does it connect to MySQL?
- What does it actually check? (`Hint <http://www.codership.com/wiki/doku.php?id=galera_node_fsm>`_)
- What do you need to do to make it work?  For the purposes of this tutorial, try to do it without modifying the clustercheck script, though enabling the ERR_FILE variable may help.

After you fix it, it should start working::

	[root@node1 ~]# clustercheck
	HTTP/1.1 200 OK
	Content-Type: text/plain

	Percona XtraDB Cluster Node is synced.

Note that we are going to run this as ``nobody``, so let's make sure that user can run it too::

	[root@node1 ~]# su nobody -s /bin/bash -c clustercheck
	HTTP/1.1 200 OK
	Content-Type: text/plain

	Percona XtraDB Cluster Node is synced.
	

This logs into the local mysql instance and checks the cluster status.  It should always return an HTTP result, and if it thinks the node is healthy, it will return a 200 HTTP response.  


Hooking Clustercheck up to a TCP port
--------------------------------------

HAProxy can be configured to poll this on each node, but we need to somehow set this up as a daemon listening on a port for HAProxy to talk to.  For this purpose we use xinetd.  The nuances of xinetd aren't incredibly important here, but note that it will listen on a set of ports and will fork programs to answer incoming TCP requests on those ports on request.  

Add the xinetd configuration for clustercheck by creating a file called in ``/etc/xinetd.d/mysqlchk`` with these contents::

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

Now, start xinetd::

	service xinetd restart

We can check if the service works via curl::

	curl http://192.168.70.2:9200

- Does it work?
- What happens if you curl 127.0.0.1:9200 instead?  Why?

If you've reached this point, then you have a working health check on node1.  The other nodes should already have this setup, but you can run ``baseline_haproxy.pl`` and set this up on those if you have extra time and/or want the exercise.

- Do you need to recreate the ``clustercheck`` user?
- Is this secure?  If not, what else could we do to make it more-so?
- Experiment with putting the nodes into various states to see if clustercheck reacts how you'd expect.


Configuring HAProxy for a rotation of all nodes
-----------------------------------------------

Now that we have working health checks, let's start configuring HAProxy.  For our purposes, we'll only run haproxy on node1.  Let's create a baseline config in /etc/haproxy/haproxy.cfg::

	global
	        log 127.0.0.1   local0
	        log 127.0.0.1   local1 notice
	        maxconn 4096
	        uid 99
	        gid 99
	        daemon
	        # debug
	        #quiet
	
	defaults
	        log     global
	        mode    http
	        option  tcplog
	        option  dontlognull
	        retries 3
	        option redispatch
	        maxconn 2000
	        contimeout      5000
	        clitimeout      50000
	        srvtimeout      50000
	

We're not going to go over the options here, check the `HAProxy docs <http://haproxy.1wt.eu/#docs>`_ for more information.  

Now, let's add a port that will load balance across all our nodes for reads by adding these lines to the end of the file we just created::

	listen cluster-reads 0.0.0.0:5306
	  mode tcp
	  balance leastconn
	  option  httpchk

	  server node1 192.168.70.2:3306 check port 9200 
	  server node2 192.168.70.3:3306 check port 9200 
	  server node3 192.168.70.4:3306 check port 9200
	

This is setting up a port 5306.  It will balance connections to the server with the least number of connections.  It will use HTTP for healthchecking (``httpchk``).  Finally, it will use all three of our nodes as potential targets, and monitor them on port 9200.

Let's startup HAProxy to see if it's working::

	service haproxy start

Try to connect to 5306 (telnet or the mysql client is fine)::

	[root@node1 haproxy]# telnet 127.0.0.1 5306
	Trying 127.0.0.1...
	Connected to 127.0.0.1.
	Escape character is '^]'.
	J
	5.5.24?]64A+P2?WZ?k|PZTsf(3mysql_native_password

If you see a MySQL version, HAProxy is working!

Let's setup a MySQL user so we can connect as a normal client::

	node1 mysql> grant all on test.* to test@'%';

Now connect to mysql directly::

	[root@node1 ~]# mysql -u test -h 192.168.70.2
	Welcome to the MySQL monitor.  Commands end with ; or \g.
	Your MySQL connection id is 7615
	Server version: 5.5.24 Percona XtraDB Cluster (GPL), wsrep_23.6.r340

	Copyright (c) 2000, 2011, Oracle and/or its affiliates. All rights reserved.

	Oracle is a registered trademark of Oracle Corporation and/or its
	affiliates. Other names may be trademarks of their respective
	owners.

	Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

	node1 mysql>

Now connect through our HAProxy port (5306) and query the ``wsrep_node_name`` to see what node we are connected to::

	[root@node1 ~]# mysql -u test -h 192.168.70.2 -P 5306 -e "show variables like 'wsrep_node_name';"
	+-----------------+-------+
	| Variable_name   | Value |
	+-----------------+-------+
	| wsrep_node_name | node1 |
	+-----------------+-------+

- What happens when you reconnect?
- How would you configure your application clients to use this load balanced rotation?
- How would you have to setup GRANTs for application users in this case?


Using the HAProxy admin page
----------------------------

We seem to have a working HAproxy configuration, but it would be nice to see the status of the nodes.  Add the following config to your ``haproxy.cfg``::

	listen admin_page 0.0.0.0:9999
		mode http
	  balance roundrobin
		stats uri /

Then restart haproxy and visit `http://192.168.70.2:9999/ <http://192.168.70.2:9999/>`_ in your browser.

- What do you see?
- Make a connection through the HAProxy port, does it show up in the interface?
- Shutdown mysqld on one of your nodes, what is the effect in the interface?


Configuring HAProxy for a writer port
-------------------------------------

Our reader port is a load-balanced rotation of all nodes.  However, for writes we may not want to send traffic to all the nodes, but only to one to avoid deadlocking errors.  Since PXC has synchronous replication, it's not hard to fail over writes, but we want to ensure that writes only go to a single node at a time, but can also failover automatically if that node goes down.  

Let's add the following config to the ``haproxy.cfg``::

	listen cluster-writes 0.0.0.0:4306
	    mode tcp
	    balance leastconn
	    option  httpchk

	    server node1 192.168.70.2:3306 check port 9200
	    server node2 192.168.70.3:3306 check port 9200 backup
	    server node3 192.168.70.4:3306 check port 9200 backup

This looks very similar to our previous configuration, except for the port number and the presence of the 'backup' flag.  Restart haproxy and test the connection to see what node you reach::

	[root@node1 ~]# mysql -u test -h 192.168.70.2 -P 4306 -e "show variables like 'wsrep_node_name';"

- How does this look in the HAProxy admin page?
- Where do the connections go if node1 fails?
- What happens to connections already on node2 if node1 recovers?  Is there any way to fix this?


