Progressive PXC Setup
=====================

.. contents:: 
   :backlinks: entry
   :local:

Assumptions
------------

- ``vagrant up`` complete and successful


Step 0: baseline the nodes
--------------------------

We are assuming here that you have successfully run `vagrant up` and created the 3 node PXC cluster using puppet.  Since this tutorial is intended to teach you how to migrate from an existing MySQL instance into a PXC cluster, we are now going to undo some of that work to give you a good baseline to start with.  To baseline your nodes, simply run::

	host> ./baseline.pl

This will stop mysql on all your nodes, remove the my.cnf and wipe the datadirs.


Step 1: Setup node1 as standalone MySQL
---------------------------------------

First we will setup a single node as a standalone MySQL server without any cluster goodness.  The existing PXC server package can function in standalone mode just fine, so we won't trouble with replacing the packages, but instead we'll just *pretend* this is normal MySQL software.

Let's create a my.cnf file and add some basic configuration so we can startup our server. 

``node1:/etc/my.cnf``::

	[mysqld]
	datadir=/var/lib/mysql
	user=mysql
	log_error=error.log

	binlog_format=ROW

	bind-address=192.168.70.2
	innodb_log_file_size=64M

	[mysql]
	prompt="node1 mysql> "

	[client]
	user=root

There's nothing too fancy happening here.  We're just setting some reasonable defaults and not a lot else. Now let's start mysql::

	[root@node1 ~]# service mysql start
	Starting MySQL (Percona Server).. SUCCESS!

Because this server does contain the Galera patch, we can query the cluster status and determine that this node is not a member of a cluster::

	[root@node1 ~]# mysql
	Welcome to the MySQL monitor.  Commands end with ; or \g.
	Your MySQL connection id is 9
	Server version: 5.5.24 Percona XtraDB Cluster (GPL), wsrep_23.6.r340

	Copyright (c) 2000, 2011, Oracle and/or its affiliates. All rights reserved.

	Oracle is a registered trademark of Oracle Corporation and/or its
	affiliates. Other names may be trademarks of their respective
	owners.

	Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

	node1 mysql> show status like 'wsrep_cluster_status';
	+----------------------+--------------+
	| Variable_name        | Value        |
	+----------------------+--------------+
	| wsrep_cluster_status | Disconnected |
	+----------------------+--------------+
	1 row in set (0.00 sec)


Step 2: Load some baseline data
-------------------------------
	
At this point, we have a working standalone MySQL server.  Let's put some data on it.  Puppet should have downloaded the sakila database to your /root directory.  Let's unzip it and load it into this node::

	[root@node1 ~]# ls -la /root/sakila-db.zip 
	-rw-r--r-- 1 root root 720320 Dec 15  2011 /root/sakila-db.zip
	[root@node1 ~]# cd /root
	[root@node1 ~]# unzip sakila-db.zip 
	Archive:  sakila-db.zip
	   creating: sakila-db/
	  inflating: sakila-db/sakila-schema.sql  
	  inflating: sakila-db/sakila.mwb    
	  inflating: sakila-db/sakila-data.sql  
	[root@node1 ~]# mysql < sakila-db/sakila-schema.sql 
	[root@node1 ~]# mysql < sakila-db/sakila-data.sql 
	[root@node1 ~]# mysql sakila
	Reading table information for completion of table and column names
	You can turn off this feature to get a quicker startup with -A
	
	Welcome to the MySQL monitor.  Commands end with ; or \g.
	Your MySQL connection id is 3
	Server version: 5.5.24 Percona XtraDB Cluster (GPL), wsrep_23.6.r340
	
	Copyright (c) 2000, 2011, Oracle and/or its affiliates. All rights reserved.
	
	Oracle is a registered trademark of Oracle Corporation and/or its
	affiliates. Other names may be trademarks of their respective
	owners.
	
	Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
	
	node1 mysql> show tables;
	+----------------------------+
	| Tables_in_sakila           |
	+----------------------------+
	| actor                      |
	| actor_info                 |
	| address                    |
	| category                   |
	| city                       |
	| country                    |
	| customer                   |
	| customer_list              |
	| film                       |
	| film_actor                 |
	| film_category              |
	| film_list                  |
	| film_text                  |
	| inventory                  |
	| language                   |
	| nicer_but_slower_film_list |
	| payment                    |
	| rental                     |
	| sales_by_film_category     |
	| sales_by_store             |
	| staff                      |
	| staff_list                 |
	| store                      |
	+----------------------------+
	23 rows in set (0.00 sec)

If you can't find the sakila-db.zip, download it, it's not very large::

	[root@node1 ~]# wget http://downloads.mysql.com/docs/sakila-db.zip


Step 3: Convert node1 to a cluster
----------------------------------

So now node1 is setup as a baseline MySQL server with a small sample database loaded.  From here we want to get ready to migrate to PXC.  We first need to add the necessary configuration to our my.cnf to prepare this node to be part of our cluster.  Here's what we need to add, be sure to add it to the correct section(s) our config:

``node1:/etc/my.cnf``::

	[mysqld_safe]
	wsrep_urls=gcomm://
	
	[mysqld]
	...
	wsrep_cluster_name=trimethylxanthine
	wsrep_cluster_address=
	wsrep_node_name=node1
	wsrep_node_address=192.168.70.2
	
	wsrep_provider=/usr/lib64/libgalera_smm.so
	
	wsrep_sst_method=xtrabackup
	
	wsrep_slave_threads=2
	
	innodb_locks_unsafe_for_binlog=1
	innodb_autoinc_lock_mode=2
	...

Let's look at each option and what it means:

wsrep_urls
	a list of urls to try to find an existing cluster.  In this case we want to start a new cluster, so we specify an empty ``gcomm://``.

wsrep_cluster_name
	a unique identifier for this cluster

wsrep_cluster_address
	This is an address for the node to connect to the cluster.  We leave this empty because we now use ``wsrep_urls`` to help us discover other cluster nodes.  If we do not explicitly leave this blank, it gets set to ``gcomm://``, which, of course, starts a new cluster.  We'd rather control that via the ``wsrep_urls`` variable.

wsrep_node_name
	a unique identifier for this node

wsrep_node_address
	a shortcut setting that sets up the cluster communication, SST and IST addresses for us.  In our case, this is the IP configured on each node for all inter-node communication.  This will be different on each node.

wsrep_provider
	path to libgalera

wsrep_sst_method
	The method we use to do full state transfers between nodes.  Xtrabackup in this case.

wsrep_slave_threads
	How many threads can apply worksets in parallel on this node
	
innodb_locks_unsafe_for_binlog, innodb_autoinc_lock_mode=2
	Required for Galera
	
After you have added this configuration, tail the mysql error log and restart mysql:

screen1::

	tail -f /var/lib/mysql/error.log

screen2::

	service mysql restart

You should see something similar in screen1 like following when the server restarts::

	120809 21:06:37 mysqld_safe mysqld from pid file /var/lib/mysql/node1.pid ended
	120809 21:06:52 mysqld_safe Starting mysqld daemon with databases from /var/lib/mysql
	120809 21:06:52 [Note] Flashcache bypass: disabled
	120809 21:06:52 [Note] Flashcache setup error is : ioctl failed
	
	120809 21:06:52 [Note] WSREP: Read nil XID from storage engines, skipping position init
	120809 21:06:52 [Note] WSREP: wsrep_load(): loading provider library '/usr/lib64/libgalera_smm.so'
	120809 21:06:52 [Note] WSREP: wsrep_load(): Galera 2.1(r113) by Codership Oy <info@codership.com> loaded succesfully.
	120809 21:06:52 [Warning] WSREP: Could not open saved state file for reading: /var/lib/mysql//grastate.dat
	120809 21:06:52 [Note] WSREP: Found saved state: 00000000-0000-0000-0000-000000000000:-1
	120809 21:06:52 [Note] WSREP: Preallocating 134219048/134219048 bytes in '/var/lib/mysql//galera.cache'...
	120809 21:06:52 [Note] WSREP: Passing config to GCS: base_host = 192.168.70.2; gcache.dir = /var/lib/mysql/; gcache.keep_pages_size = 0; gcache.mem_size = 0; gcache.name = /var/lib/mysql//galera.cache; gcache.page_size = 128M; gcache.size = 128M; gcs.fc_debug = 0; gcs.fc_factor = 0.5; gcs.fc_limit = 16; gcs.fc_master_slave = NO; gcs.max_packet_size = 64500; gcs.max_throttle = 0.25; gcs.recv_q_hard_limit = 9223372036854775807; gcs.recv_q_soft_limit = 0.25; gcs.sync_donor = NO; replicator.causal_read_timeout = PT30S; replicator.commit_order = 3
	120809 21:06:52 [Note] WSREP: Assign initial position for certification: -1, protocol version: -1
	120809 21:06:52 [Note] WSREP: wsrep_sst_grab()
	120809 21:06:52 [Note] WSREP: Start replication
	120809 21:06:52 [Note] WSREP: Setting initial position to 00000000-0000-0000-0000-000000000000:-1
	120809 21:06:52 [Note] WSREP: protonet asio version 0
	120809 21:06:52 [Note] WSREP: backend: asio
	120809 21:06:52 [Note] WSREP: GMCast version 0
	120809 21:06:52 [Note] WSREP: (613617f2-e255-11e1-0800-84cc659255da, 'tcp://0.0.0.0:4567') listening at tcp://0.0.0.0:4567
	120809 21:06:52 [Note] WSREP: (613617f2-e255-11e1-0800-84cc659255da, 'tcp://0.0.0.0:4567') multicast: , ttl: 1
	120809 21:06:52 [Note] WSREP: EVS version 0
	120809 21:06:52 [Note] WSREP: PC version 0
	120809 21:06:52 [Note] WSREP: gcomm: connecting to group 'trimethylxanthine', peer ''
	120809 21:06:52 [Note] WSREP: view(view_id(PRIM,613617f2-e255-11e1-0800-84cc659255da,1) memb {
	        613617f2-e255-11e1-0800-84cc659255da,
	} left {
	} partitioned {
	})
	120809 21:06:52 [Note] WSREP: gcomm: connected
	120809 21:06:52 [Note] WSREP: Changing maximum packet size to 64500, resulting msg size: 32636
	120809 21:06:52 [Note] WSREP: Shifting CLOSED -> OPEN (TO: 0)
	120809 21:06:52 [Note] WSREP: Opened channel 'trimethylxanthine'
	120809 21:06:52 [Note] WSREP: Waiting for SST to complete.
	120809 21:06:52 [Note] WSREP: New COMPONENT: primary = yes, bootstrap = no, my_idx = 0, memb_num = 1
	120809 21:06:52 [Note] WSREP: Starting new group from scratch: 613693f7-e255-11e1-0800-7cf8f5cc663d
	120809 21:06:52 [Note] WSREP: STATE_EXCHANGE: sent state UUID: 6136aae9-e255-11e1-0800-eee50a9ab0f3
	120809 21:06:52 [Note] WSREP: STATE EXCHANGE: sent state msg: 6136aae9-e255-11e1-0800-eee50a9ab0f3
	120809 21:06:52 [Note] WSREP: STATE EXCHANGE: got state msg: 6136aae9-e255-11e1-0800-eee50a9ab0f3 from 0 (node1)
	120809 21:06:52 [Note] WSREP: Quorum results:
	        version    = 2,
	        component  = PRIMARY,
	        conf_id    = 0,
	        members    = 1/1 (joined/total),
	        act_id     = 0,
	        last_appl. = -1,
	        protocols  = 0/4/2 (gcs/repl/appl),
	        group UUID = 613693f7-e255-11e1-0800-7cf8f5cc663d
	120809 21:06:52 [Note] WSREP: Flow-control interval: [8, 16]
	120809 21:06:52 [Note] WSREP: Restored state OPEN -> JOINED (0)
	120809 21:06:52 [Note] WSREP: New cluster view: global state: 613693f7-e255-11e1-0800-7cf8f5cc663d:0, view# 1: Primary, number of nodes: 1, my index: 0, protocol version 2
	120809 21:06:52 [Note] WSREP: SST complete, seqno: 0
	120809 21:06:52 [Note] WSREP: Member 0 (node1) synced with group.
	120809 21:06:52 [Note] WSREP: Shifting JOINED -> SYNCED (TO: 0)
	120809 21:06:52 [Note] Plugin 'FEDERATED' is disabled.
	120809 21:06:52 InnoDB: The InnoDB memory heap is disabled
	120809 21:06:52 InnoDB: Mutexes and rw_locks use GCC atomic builtins
	120809 21:06:52 InnoDB: Compressed tables use zlib 1.2.3
	120809 21:06:52 InnoDB: Using Linux native AIO
	120809 21:06:52 InnoDB: Initializing buffer pool, size = 128.0M
	120809 21:06:52 InnoDB: Completed initialization of buffer pool
	120809 21:06:52 InnoDB: highest supported file format is Barracuda.
	120809 21:06:52  InnoDB: Waiting for the background threads to start
	120809 21:06:53 Percona XtraDB (http://www.percona.com) 1.1.8-rel25.3 started; log sequence number 8566400
	120809 21:06:53 [Note] Server hostname (bind-address): '192.168.70.2'; port: 3306
	120809 21:06:53 [Note]   - '192.168.70.2' resolves to '192.168.70.2';
	120809 21:06:53 [Note] Server socket created on IP: '192.168.70.2'.
	120809 21:06:53 [Note] Event Scheduler: Loaded 0 events
	120809 21:06:53 [Note] WSREP: wsrep_notify_cmd is not defined, skipping notification.
	120809 21:06:53 [Note] WSREP: Assign initial position for certification: 0, protocol version: 2
	120809 21:06:53 [Note] WSREP: Synchronized with group, ready for connections
	120809 21:06:53 [Note] WSREP: wsrep_notify_cmd is not defined, skipping notification.
	120809 21:06:53 [Note] /usr/sbin/mysqld: ready for connections.
	Version: '5.5.24'  socket: '/var/lib/mysql/mysql.sock'  port: 3306  Percona XtraDB Cluster (GPL), wsrep_23.6.r340

Note the following::

	WSREP: Could not open saved state file for reading: /var/lib/mysql//grastate.dat

The `grastate.dat` is the state file for Galera, and initializing means that we have taken this mysql database (everything we already loaded) and made it the baseline for this cluster.  

Let's check the status of our node::

	node1 mysql> show status like 'wsrep_local_state_comment';
	+---------------------------+------------+
	| Variable_name             | Value      |
	+---------------------------+------------+
	| wsrep_local_state_comment | Synced (6) |
	+---------------------------+------------+
	1 row in set (0.00 sec)

So we can see that we have created a cluster.  Also check the values of ``show status like 'wsrep%';``, and verify our sample data is still present.


Step 4: Setup and add node2
--------------------------

At this point we want to add node2 to our existing cluster (of 1 node).  This is quite simple, first copy node1's configuration to node2, and make a few modifications to apply the config to node2.  Try to do this yourself first, and then compare with the following file to ensure you got all the changes.  **DO NOT START MYSQL YET**

node2:/etc/my.cnf::

	[mysqld]
	datadir=/var/lib/mysql
	user=mysql
	log_error=error.log
	
	binlog_format=ROW
	
	bind-address=192.168.70.3
	innodb_log_file_size=64M
	
	wsrep_cluster_name=trimethylxanthine
	wsrep_cluster_address=
	wsrep_node_name=node2
	wsrep_node_address=192.168.70.3
	
	wsrep_provider=/usr/lib64/libgalera_smm.so
	
	wsrep_sst_method=xtrabackup
	
	wsrep_slave_threads=2
	
	innodb_locks_unsafe_for_binlog=1
	innodb_autoinc_lock_mode=2
	
	[mysql]
	prompt="node2 mysql> "
	
	[client]
	user=root


Connecting to an unreachable cluster
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This configuration sets up node2 to be a cluster node, but it's missing how to connect to the existing cluster.  To do that we add these lines::

	[mysqld_safe]
	wsrep_urls=gcomm://192.168.70.3:4567,gcomm://192.168.70.4:4567

This tells our node to try to find an existing cluster on these targets.  If it cannot find an existing node to connect to, it should not be able to start.  The astute will realize that I have not included the address of node1 here.  Let's see what happens when it cannot find a node to connect to::

	[root@node2 ~]# service mysql start
	Starting MySQL (Percona Server). ERROR! The server quit without updating PID file (/var/lib/mysql/node2.pid).
	[root@node2 ~]# tail -n 5 /var/lib/mysql/error.log 
	120809 22:06:35 mysqld_safe ERROR: none of the URLs in 'gcomm://192.168.70.3:4567,gcomm://192.168.70.4:4567' is reachable.
	120809 22:06:35 [ERROR] WSREP: xtrabackup SST method requires wsrep_cluster_address to be configured on startup.
	120809 22:06:35 [ERROR] Aborting

	120809 22:06:35 mysqld_safe mysqld from pid file /var/lib/mysql/node2.pid ended

We get an error.  The error.log tells us clearly that none of our connections in ``wsrep_urls`` was reachable.  In an existing cluster, we don't want another cluster to be formed, so this is the correct behavior.


Connecting to a reachable cluster
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now, let's add node1's ip to our ``wsrep_urls`` on node2::

	wsrep_urls=gcomm://192.168.70.2:4567,gcomm://192.168.70.3:4567,gcomm://192.168.70.4:4567

When we start mysql now::

	120809 22:14:50 mysqld_safe Starting mysqld daemon with databases from /var/lib/mysql
	120809 22:14:50 [Note] Flashcache bypass: disabled
	120809 22:14:50 [Note] Flashcache setup error is : ioctl failed

	120809 22:14:50 [Note] WSREP: Read nil XID from storage engines, skipping position init
	120809 22:14:50 [Note] WSREP: wsrep_load(): loading provider library '/usr/lib64/libgalera_smm.so'
	120809 22:14:50 [Note] WSREP: wsrep_load(): Galera 2.1(r113) by Codership Oy <info@codership.com> loaded succesfully.
	120809 22:14:50 [Warning] WSREP: Could not open saved state file for reading: /var/lib/mysql//grastate.dat
	120809 22:14:50 [Note] WSREP: Found saved state: 00000000-0000-0000-0000-000000000000:-1
	120809 22:14:50 [Note] WSREP: Preallocating 134219048/134219048 bytes in '/var/lib/mysql//galera.cache'...
	120809 22:14:50 [Note] WSREP: Passing config to GCS: base_host = 192.168.70.3; gcache.dir = /var/lib/mysql/; gcache.keep_pages_size = 0; gcache.mem_size = 0; gcache.name = /var/lib/mysql//galera.cache; gcache.page_size = 128M; gcache.size = 128M; gcs.fc_debug = 0; gcs.fc_factor = 0.5; gcs.fc_limit = 16; gcs.fc_master_slave = NO; gcs.max_packet_size = 64500; gcs.max_throttle = 0.25; gcs.recv_q_hard_limit = 9223372036854775807; gcs.recv_q_soft_limit = 0.25; gcs.sync_donor = NO; replicator.causal_read_timeout = PT30S; replicator.commit_order = 3
	120809 22:14:50 [Note] WSREP: Assign initial position for certification: -1, protocol version: -1
	120809 22:14:50 [Note] WSREP: wsrep_sst_grab()
	120809 22:14:50 [Note] WSREP: Start replication
	120809 22:14:50 [Note] WSREP: Setting initial position to 00000000-0000-0000-0000-000000000000:-1
	120809 22:14:50 [Note] WSREP: protonet asio version 0
	120809 22:14:50 [Note] WSREP: backend: asio
	120809 22:14:50 [Note] WSREP: GMCast version 0
	120809 22:14:50 [Note] WSREP: (dfe78b31-e25e-11e1-0800-52f6ac846394, 'tcp://0.0.0.0:4567') listening at tcp://0.0.0.0:4567
	120809 22:14:50 [Note] WSREP: (dfe78b31-e25e-11e1-0800-52f6ac846394, 'tcp://0.0.0.0:4567') multicast: , ttl: 1
	120809 22:14:50 [Note] WSREP: EVS version 0
	120809 22:14:50 [Note] WSREP: PC version 0
	120809 22:14:50 [Note] WSREP: gcomm: connecting to group 'trimethylxanthine', peer '192.168.70.2:4567'
	120809 22:14:51 [Note] WSREP: declaring 6fad1223-e25d-11e1-0800-1de1ae0ad7d6 stable
	120809 22:14:51 [Note] WSREP: view(view_id(PRIM,6fad1223-e25d-11e1-0800-1de1ae0ad7d6,2) memb {
	        6fad1223-e25d-11e1-0800-1de1ae0ad7d6,
	        dfe78b31-e25e-11e1-0800-52f6ac846394,
	} joined {
	} left {
	} partitioned {
	})
	120809 22:14:51 [Note] WSREP: gcomm: connected
	120809 22:14:51 [Note] WSREP: Changing maximum packet size to 64500, resulting msg size: 32636
	120809 22:14:51 [Note] WSREP: Shifting CLOSED -> OPEN (TO: 0)
	120809 22:14:51 [Note] WSREP: Opened channel 'trimethylxanthine'
	120809 22:14:51 [Note] WSREP: Waiting for SST to complete.
	120809 22:14:51 [Note] WSREP: New COMPONENT: primary = yes, bootstrap = no, my_idx = 1, memb_num = 2
	120809 22:14:51 [Note] WSREP: STATE EXCHANGE: Waiting for state UUID.
	120809 22:14:51 [Note] WSREP: STATE EXCHANGE: sent state msg: e02ebf3f-e25e-11e1-0800-54018c45c4f6
	120809 22:14:51 [Note] WSREP: STATE EXCHANGE: got state msg: e02ebf3f-e25e-11e1-0800-54018c45c4f6 from 0 (node1)
	120809 22:14:51 [Note] WSREP: STATE EXCHANGE: got state msg: e02ebf3f-e25e-11e1-0800-54018c45c4f6 from 1 (node2)
	120809 22:14:51 [Note] WSREP: Quorum results:
	        version    = 2,
	        component  = PRIMARY,
	        conf_id    = 1,
	        members    = 1/2 (joined/total),
	        act_id     = 0,
	        last_appl. = -1,
	        protocols  = 0/4/2 (gcs/repl/appl),
	        group UUID = 6fad8438-e25d-11e1-0800-eba2b7db20ad
	120809 22:14:51 [Note] WSREP: Flow-control interval: [12, 23]
	120809 22:14:51 [Note] WSREP: Shifting OPEN -> PRIMARY (TO: 0)
	120809 22:14:51 [Note] WSREP: State transfer required: 
	        Group state: 6fad8438-e25d-11e1-0800-eba2b7db20ad:0
	        Local state: 00000000-0000-0000-0000-000000000000:-1
	120809 22:14:51 [Note] WSREP: New cluster view: global state: 6fad8438-e25d-11e1-0800-eba2b7db20ad:0, view# 2: Primary, number of nodes: 2, my index: 1, protocol version 2
	120809 22:14:51 [Warning] WSREP: Gap in state sequence. Need state transfer.
	120809 22:14:53 [Note] WSREP: Running: 'wsrep_sst_xtrabackup 'joiner' '192.168.70.3' '' '/var/lib/mysql/' '/etc/my.cnf' '17076' 2>sst.err'
	120809 22:14:53 [Note] WSREP: Prepared SST request: xtrabackup|192.168.70.3:4444/xtrabackup_sst
	120809 22:14:53 [Note] WSREP: wsrep_notify_cmd is not defined, skipping notification.
	120809 22:14:53 [Note] WSREP: Assign initial position for certification: 0, protocol version: 2
	120809 22:14:53 [Warning] WSREP: Failed to prepare for incremental state transfer: Local state UUID (00000000-0000-0000-0000-000000000000) does not match group state UUID (6fad8438-e25d-11e1-0800-eba2b7db20ad): 1 (Operation not permitted)
	         at galera/src/replicator_str.cpp:prepare_for_IST():439. IST will be unavailable.
	120809 22:14:53 [Note] WSREP: Node 1 (node2) requested state transfer from '*any*'. Selected 0 (node1)(SYNCED) as donor.
	120809 22:14:53 [Note] WSREP: Shifting PRIMARY -> JOINER (TO: 0)
	120809 22:14:53 [Note] WSREP: Requesting state transfer: success, donor: 0
	120809 22:15:30 [Note] WSREP: 0 (node1): State transfer to 1 (node2) complete.
	120809 22:15:30 [Note] WSREP: Member 0 (node1) synced with group.
	120809 22:15:41 [Note] WSREP: SST complete, seqno: 0
	120809 22:15:41 [Note] Plugin 'FEDERATED' is disabled.
	120809 22:15:41 InnoDB: The InnoDB memory heap is disabled
	120809 22:15:41 InnoDB: Mutexes and rw_locks use GCC atomic builtins
	120809 22:15:41 InnoDB: Compressed tables use zlib 1.2.3
	120809 22:15:41 InnoDB: Using Linux native AIO
	120809 22:15:41 InnoDB: Initializing buffer pool, size = 128.0M
	120809 22:15:41 InnoDB: Completed initialization of buffer pool
	120809 22:15:41 InnoDB: highest supported file format is Barracuda.
	120809 22:15:41  InnoDB: Waiting for the background threads to start
	120809 22:15:42 Percona XtraDB (http://www.percona.com) 1.1.8-rel25.3 started; log sequence number 8566796
	120809 22:15:42 [Note] Server hostname (bind-address): '192.168.70.3'; port: 3306
	120809 22:15:42 [Note]   - '192.168.70.3' resolves to '192.168.70.3';
	120809 22:15:42 [Note] Server socket created on IP: '192.168.70.3'.
	120809 22:15:42 [Note] Event Scheduler: Loaded 0 events
	120809 22:15:42 [Note] WSREP: Signalling provider to continue.
	120809 22:15:42 [Note] WSREP: Received SST: 6fad8438-e25d-11e1-0800-eba2b7db20ad:0
	120809 22:15:42 [Note] WSREP: SST received: 6fad8438-e25d-11e1-0800-eba2b7db20ad:0
	120809 22:15:42 [Note] /usr/sbin/mysqld: ready for connections.
	Version: '5.5.24'  socket: '/var/lib/mysql/mysql.sock'  port: 3306  Percona XtraDB Cluster (GPL), wsrep_23.6.r340
	120809 22:15:42 [Note] WSREP: 1 (node2): State transfer from 0 (node1) complete.
	120809 22:15:42 [Note] WSREP: Shifting JOINER -> JOINED (TO: 0)
	120809 22:15:42 [Note] WSREP: Member 1 (node2) synced with group.
	120809 22:15:42 [Note] WSREP: Shifting JOINED -> SYNCED (TO: 0)
	120809 22:15:42 [Note] WSREP: Synchronized with group, ready for connections
	120809 22:15:42 [Note] WSREP: wsrep_notify_cmd is not defined, skipping notification.

We can see here (with a bit of verbosity) that our node did an xtrabackup SST that took about a minute. 


Step 5: Checking cluster status
---------------------------------

Manually checking status
~~~~~~~~~~~~~~~~~~~~~~~~

Let's check the node status::

	node2 mysql> show status like 'wsrep%';
	+----------------------------+--------------------------------------+
	| Variable_name              | Value                                |
	+----------------------------+--------------------------------------+
	...
	| wsrep_local_state_comment  | Synced (6)                           |
	...
	| wsrep_cluster_size         | 2                                    |
	...
	| wsrep_cluster_status       | Primary                              |
	| wsrep_connected            | ON                                   |
	...
	| wsrep_ready                | ON                                   |
	+----------------------------+--------------------------------------+
	39 rows in set (0.00 sec)

We can see from this that:

wsrep_local_state_comment
	We are synchronized with the cluster

wsrep_cluster_size
	There are now 2 nodes in the cluster

wsrep_cluster_status
	Primary means we have quorum of all known cluster nodes

wsrep_connected
	Galera replication is connected.

wsrep_ready
	Ready to handle SQL work.

Check node1 and confirm the state is the same.  Also, we can confirm that the data on node2 was correctly transferred from node1::

	node2 mysql> use sakila;
	Reading table information for completion of table and column names
	You can turn off this feature to get a quicker startup with -A
	
	Database changed
	node2 mysql> show tables;
	+----------------------------+
	| Tables_in_sakila           |
	+----------------------------+
	| actor                      |
	| actor_info                 |
	| address                    |
	| category                   |
	| city                       |
	| country                    |
	| customer                   |
	| customer_list              |
	| film                       |
	| film_actor                 |
	| film_category              |
	| film_list                  |
	| film_text                  |
	| inventory                  |
	| language                   |
	| nicer_but_slower_film_list |
	| payment                    |
	| rental                     |
	| sales_by_film_category     |
	| sales_by_store             |
	| staff                      |
	| staff_list                 |
	| store                      |
	+----------------------------+
	23 rows in set (0.00 sec)
	
	node2 mysql> select count(*) from actor;
	+----------+
	| count(*) |
	+----------+
	|      200 |
	+----------+
	1 row in set (0.00 sec)

Verify this matches node1.


Checking status with myq_status
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

myq_status is a script from `myq_gadgets <https://github.com/jayjanssen/myq_gadgets>`_ which has a mode that reports the status of a wsrep cluster node.  Run it like this::

	[root@node1 ~]# myq_status -t 1 wsrep
	Wsrep    Cluster         Node                 Flow        Replicated      Received
	    time stat conf size   rdy  cmt  ctd dist  paus sent   que  ops size   que  ops size
	15:50:55 Prim    2    2    ON Sync   ON    0     0    0     0    0    0     0  6.0  375
	15:50:56 Prim    2    2    ON Sync   ON    0     0    0     0    0    0     0    0    0
	15:50:57 Prim    2    2    ON Sync   ON    0     0    0     0    0    0     0    0    0
	15:50:58 Prim    2    2    ON Sync   ON    0     0    0     0    0    0     0    0    0
	15:50:59 Prim    2    2    ON Sync   ON    0     0    0     0    0    0     0    0    0
	^C

This shows us a nice summarization of some ``wsrep%`` variables in near-realtime.  Note that:

- Our cluster has 2 nodes
- Our cluster is at config 2 (this increments every time a node joins or leaves the cluster)
- This node (node1) belongs to the ``Prim`` (Primary) cluster; that is, the cluster with quorum.
- This node is ready



Step 6: Add node3
---------------------------------

You should know enough now to add node3 to the cluster