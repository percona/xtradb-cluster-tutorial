Migrate Master Slave to Cluster
=========================================

This module will take an existing master and 2 slave cluster and migrate it to PXC with minimal downtime.  

.. contents:: 
   :backlinks: entry
   :local:


Check node state
----------------------------------

Your install should have all three nodes setup.  Node1 should be the master and nodes 2 and 3 should be slaves.  

**Verify you can connect to all 3 nodes, mysql is running, and the slaves are connected properly**

These servers are configured, but there is no data.  Let's use sysbench to create some test data and run a simulated workload against it on the master::

	[root@node1 ~]# sysbench --test=sysbench_tests/db/common.lua \
		--mysql-user=root --mysql-db=test --oltp-table-size=250000 \
		prepare
	
	[root@node1 ~]# sysbench --test=sysbench_tests/db/oltp.lua \
		--mysql-user=root --mysql-db=test --oltp-table-size=250000 \
		--report-interval=1 --max-requests=0 --tx-rate=10 run | grep tps


The sysbench run should output the current transaction rate and response time every second.  

**Prepare and run a sysbench test on node1, confirm replication is working to the slaves**


Update one slave to PXC
------------------------

Now that we have a verified working Master/Slave environment with real load, we want to take one of the slaves (we'll start with node3) and convert that to the PXC software.  Each Percona Server package has a PXC equivalent, and PXC is a drop in replacement for Percona server, so we'll simply remove Percona Server and install PXC::

	[root@node3 ~]# service mysql stop
	[root@node3 ~]# yum remove Percona-Server-server-55 Percona-Server-client-55
	[root@node3 ~]# yum install Percona-XtraDB-Cluster-server Percona-XtraDB-Cluster-client
	[root@node3 ~]# service mysql start
	[root@node3 ~]# mysql -e "show slave status\G"

MySQL should startup correctly, and replication should resume from the master.    

**Remove the Percona Server package and replace it with PXC.  Restart mysql and verify the slave still works properly**


Configure node3 as a 1 node cluster
------------------------------------

At this point node3 is running PXC, but none of the cluster configuration has been done.  Therefore, it is acting simply as a regular MySQL slave.  We will now add Galera configuration to the node to register it as a cluster (of 1).  

**Configure node3 with the appropriate wsrep settings in /etc/my.cnf and restart mysql**

Make node3:/etc/my.cnf look like this::

	[mysqld]
	server-id                       = 3
	binlog_format                   = ROW

	# galera settings
	wsrep_provider                  = /usr/lib/libgalera_smm.so

	wsrep_cluster_name              = mycluster
	wsrep_cluster_address           = gcomm://
	wsrep_node_name                 = node3
	wsrep_node_address              = 192.168.70.4

	wsrep_sst_method                = xtrabackup

	# innodb settings for galera
	innodb_locks_unsafe_for_binlog  = 1
	innodb_autoinc_lock_mode        = 2

Now restart mysql on node3::

	[root@node3 ~]# service mysql restart
	
MySQL should restart correctly and resume replication as before.  However, this time it is also acting as a cluster.

**Verify MySQL restarts correctly and replication resumes**


Check cluster state
--------------------

We've configured node3 as our initial cluster node.  What's more is that we will use node3 as the bridge between the current master and the cluster.  We want to ensure it is configured properly before going further.  

To check the cluster state, we will use the ``myq_status`` tool.  Execute::

[root@node3 ~]# myq_status -t 1 wsrep

This tool shows us information about the node state.  Try to determine:

- How many nodes are in the cluster?
- Is the cluster "Primary"?
- Are cluster replication events being generated?

**Run myq_status on node3 and try to answer the above questions before continuing**

You might notice that in spite of replication from node1 flowing into node3, the PXC cluster is not generating any replication events!  

::

	[root@node3 ~]# myq_status -t 1 wsrep
	Wsrep    Cluster        Node           Queue   Ops     Bytes     Flow        Conflct
	    time  name P cnf  #  name  cmt sta  Up  Dn  Up  Dn   Up   Dn pau snt dst lcf bfa
	[mysqld]
	08:49:25 myclu P   1  1 node3 Sync T/T   0   0   0   2    0  125 0.0   0   0   0   0
	08:49:26 myclu P   1  1 node3 Sync T/T   0   0   0   0    0    0 0.0   0   0   0   0
	08:49:27 myclu P   1  1 node3 Sync T/T   0   0   0   0    0    0 0.0   0   0   0   0
	08:49:28 myclu P   1  1 node3 Sync T/T   0   0   0   0    0    0 0.0   0   0   0   0
	08:49:29 myclu P   1  1 node3 Sync T/T   0   0   0   0    0    0 0.0   0   0   0   0
	08:49:30 myclu P   1  1 node3 Sync T/T   0   0   0   0    0    0 0.0   0   0   0   0
	08:49:31 myclu P   1  1 node3 Sync T/T   0   0   0   0    0    0 0.0   0   0   0   0
	08:49:32 myclu P   1  1 node3 Sync T/T   0   0   0   0    0    0 0.0   0   0   0   0
	08:49:33 myclu P   1  1 node3 Sync T/T   0   0   0   0    0    0 0.0   0   0   0   0
	08:49:34 myclu P   1  1 node3 Sync T/T   0   0   0   0    0    0 0.0   0   0   0   0
	08:49:35 myclu P   1  1 node3 Sync T/T   0   0   0   0    0    0 0.0   0   0   0   0
	08:49:36 myclu P   1  1 node3 Sync T/T   0   0   0   0    0    0 0.0   0   0   0   0
	08:49:37 myclu P   1  1 node3 Sync T/T   0   0   0   0    0    0 0.0   0   0   0   0

It turns out we have a misconfiguration in our cluster that we need to address.  

**Try to figure out what we might need to add to the my.cnf to allow incoming standard MySQL replication events be replicated to throughout the cluster**

We need to configure ``log-slave-updates`` on node3 to treat incoming mysql replication traffic as data that should be written to the cluster.  Add this line to node3's my.cnf and restart mysql::

	log-slave-updates

**Reconfigure node3 and restart replication**

What do you see in ``myq_status`` now?

::

	[root@node3 ~]# myq_status -t 1 wsrep
	Wsrep    Cluster        Node           Queue   Ops     Bytes     Flow        Conflct
	    time  name P cnf  #  name  cmt sta  Up  Dn  Up  Dn   Up   Dn pau snt dst lcf bfa
	08:58:03 myclu P   1  1 node3 Sync T/T   0   0  4k  14 6.4M  221 0.0   0  65   0   0
	08:58:04 myclu P   1  1 node3 Sync T/T   0   0   8   0  12K    0 0.0   0  68   0   0
	08:58:05 myclu P   1  1 node3 Sync T/T   0   0  12   0  19K    0 0.0   0  72   0   0
	08:58:06 myclu P   1  1 node3 Sync T/T   0   0   9   0  14K    0 0.0   0  76   0   0
	08:58:07 myclu P   1  1 node3 Sync T/T   0   0  10   0  16K    0 0.0   0  79   0   0
	08:58:08 myclu P   1  1 node3 Sync T/T   0   0  15   0  23K    0 0.0   0  85   0   0
	08:58:09 myclu P   1  1 node3 Sync T/T   0   0   8   0  12K    0 0.0   0  88   0   0
	08:58:10 myclu P   1  1 node3 Sync T/T   0   0  10   0  16K    0 0.0   0  90   0   0
	08:58:11 myclu P   1  1 node3 Sync T/T   0   0   9   0  14K    0 0.0   0  95   0   0


At this point, we can see that we have a 1 node cluster that is 'Primary' ('P') column, and that replication events are being uploaded ('Up') to the cluster, even though there are no other cluster nodes yet.  


Preparing node2 to join the cluster
----------------------------------

At this point we're ready to move node2 into the cluster.  Node2 is also a slave of node1, and we first want to disable that replication::

	node2> slave stop;
	node2> reset slave;

This will prevent node2 from trying to also connect to node1 for replication after it joins the cluster.  Node3 has been designated for that job.  

**Reset the slave on node2**

Beyond this, we simply repeat the steps we did with node3.

**Replace the Percona Server packages with PXC as we did above on node2.  Don't change the my.cnf yet**

Because we haven't touched the my.cnf, node2 is running the PXC software, but functioning as a standalone node.  That is, it doesn't know anything about node3 yet.  Check ``myq_status`` again.  How does the output look on a node that is *not* configured with the cluster settings?

Now we need to configure node2 to allow it to join node3 as a cluster node.  For the most part, this is as simple as copying the configuration we came up with on node3.  

**Copy node3's /etc/my.cnf to node2, but do NOT restart mysql yet**

We need to make some modifications to a few settings to make this configuration appropriate for node2.  At a glance, can you figure out which settings they are?

We need to change:

- wsrep_cluster_address
- wsrep_node_name
- wsrep_node_address
- optionally the server-id

**Make the configuration changes to node2's config**

Node2's my.cnf should look like this::

	[mysqld]
	server-id=2
	binlog_format=ROW
	log-slave-updates

	# galera settings
	wsrep_provider                  = /usr/lib/libgalera_smm.so

	wsrep_cluster_name              = mycluster
	wsrep_cluster_address           = gcomm://192.168.70.2,192.168.70.3,192.168.70.4
	wsrep_node_name                 = node2
	wsrep_node_address              = 192.168.70.3

	wsrep_sst_method                =       xtrabackup

	# innodb settings for galera
	innodb_locks_unsafe_for_binlog   =  1
	innodb_autoinc_lock_mode         =  2

wsrep_node_name
	By convention, simply the short hostname of the node.  This just needs to be unique across all nodes in the cluster.

wsrep_node_address
	The IP address we're using for all Galera work.  In our case this is eth1, but it could be your primary eth0 address in a normal environment.

wsrep_cluster_address
	Describes how this node needs to connect to the cluster.  Note this contains the ips of all 3 of our nodes.  Eventually we will need to set this on all the nodes, but for now it's sufficient to set it here.  Note that this setting does *not* determine cluster membership.  It simply tells the node where it might find running cluster nodes.

	Also note that we set this to 'gcomm://' on node3 when we first started the cluster.  This option tells a node it is ok for it to form a new cluster by itself.  If this is not present, then any node trying to restart without finding another already running cluster node will fail.  This process is called *bootstrapping* the cluster.


**Do NOT restart mysql on node3 yet**


Trying to get node2 joined (and failing)
-----------------------------------------

So, it seems we're ready to restart node2.  When we restart mysql there's a lot of things that will happen, and it will be worth having windows open watching some things.  They include:

- myq_status' wsrep report on node3
- /var/lib/mysql/node*.err on both node3 and node2
- the output of 'ps axf' on node3 and node2 while node2 is trying to start

Now, let's restart mysql on node2 and see what happens.

- Does the init script report a successful start?
- What seems to happen to node3's state?
- Does node2's mysql start?  Does it keep running?

**Restart mysql on node2 and try to answer the above questions.  MySQL should ultimately fail, but you should be able to repeat the restart a few times so you can see what's going on**

Node2 is not able to join the cluster for some reason.  To figure out why, we need to take a slight tangent.


A tangent to discuss SST
--------------------------------

When a new node joins a cluster, it receives a state snapshot transfer (SST) from an existing member of the cluster.  In our case, node3 is the only valid node in the cluster, so it will be the *donor* node, and node2 will be our *joiner* node.  

If you watch ``myq_status`` you should see node3 enter the *donor* state for a bit, and then go back to *Sync*.  You should also see the node count go from 1 to 2 and back to 1 (see the *#* column).

An SST is actually just a full backup.  In our case, we configured our ``wsrep_sst_method`` to be xtrabackup.  This is taking a hot backup of node3 and streaming it to node2.  

In our case, this is failing for some reason. If you watched the process list ('px axf') on node3, you might have seen xtrabackup running.  When a donor node runs xtrabackup, a log is generated in /var/lib/mysql/innobackup.backup.log.  We should check here for an indication of what happened. 

**Check the donor node's (node3) xtrabackup SST log file to see if there are any errors**

In this case, the error message is clear::

	xtrabackup: Error: Please set parameter 'datadir'

Xtrabackup requires that the datadir be explicitly set in our my.cnf.  Let's add it::

	[mysqld]
	datadir=/var/lib/mysql
	
	...

**Add the datadir to the my.cnf file on both node3 and node2**


Yet more SST errors
--------------------

At this point we think we have solved our problem.  

**Restart mysql on node2 again and watch what happens**

- How is this different from the last time?
- Does the SST succeed?

You may have already guessed from the title of this section, but the SST is likely still failing for you.  

**Use the methods discussed above to attempt to diagnose the problem before reading further**


If I check the innobackup.backup.log on node3 again, I see this error::

	130111 09:41:33  innobackupex: Starting to lock all tables...
	innobackupex: Error: mysql child process has died: ERROR 1044 (42000) at line 3: Access denied for user ''@'localhost' to database 'mysql'
	 while waiting for reply to MySQL request: 'USE mysql;' at /usr//bin/innobackupex line 378.

Additionally, if I check the output of ``ps axf`` on node3, I see that the parent process of xtrabackup has failed::

	 3971 pts/0    S      0:00 /bin/sh /usr/bin/mysqld_safe --datadir=/var/lib/mysql --pid-file=/var/lib/mysql/node3.pid
	 4219 pts/0    Sl     1:37  \_ /usr/sbin/mysqld --basedir=/usr --datadir=/var/lib/mysql --plugin-dir=/usr/lib/mysql/plugin --user=my
	12790 pts/0    S      0:00      \_ /bin/bash -ue /usr//bin/wsrep_sst_xtrabackup --role donor --address 192.168.70.3:4444/xtrabackup_
	12803 pts/0    S      0:04          \_ nc 192.168.70.3 4444
	12929 pts/0    Sl     0:00 xtrabackup_55 --defaults-file=/etc/my.cnf --defaults-group=mysqld --backup --suspend-at-end --target-dir=

Notice how ``xtrabackup_55`` is no longer a descendant of ``mysqld``.  If we wait, the SST donation seems to be taking forever, but in reality it is hung.  

We need to somehow reset this donor node without disturbing mysql.  The easiest way to do that is to kill the ``xtrabackup_55`` process::

	[root@node3 mysql]# kill -9 12929

**Kill the pid of the xtrabackup_55 process and see if that resets node3's state**

- What happens to node3 when you kill xtrabackup?
- What happens to node2?

So, we've successfully reset the states.  But, what do we need to fix before we try again?

Xtrabackup requires `mysql access <http://www.percona.com/doc/percona-xtrabackup/innobackupex/privileges.html#permissions-and-privileges-needed>`_ to take it's backup, but we haven't configured that.

We first need to setup a user on node3::

	node3> GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'sst'@'localhost' IDENTIFIED BY 'secret';

And, we need to add an additional Galera configuration to our my.cnf so Galera knows the username and password to use::

	[mysqld]
	...
	wsrep_sst_auth=sst:secret
	...

**Create an SST user on node3 with the appropriate privileges, add the wsrep_sst_auth setting to your my.cnf files and retry mysql on node2 again**

- Does it work this time?
- What might have we forgotten?

After we add the ``wsrep_sst_auth`` setting, we need to restart mysql on node3.  

**Reset node3 again and restart mysql so the sst auth setting applies**

**Keep working on debugging node2's SST until it works**


Success at last
----------------

It can be a fight to get that first SST to work right and the above hopefully illustrates both some common problems, and some methodology to diagnosing the problem.  The good news is that once you get things figured out the first time, it's typically very easy to get an SST the first time on subsequent nodes.  

So, now we have a 2 node cluster.  Check out some things to see what they look like:

- innobackup.backup.log on node3 (look at what a successful donation log looks like)
- innobackup.prepare.log on node2
- The mysql error logs on both node2 and node3
- myq_status output on node2 and node3

**Go over the status of both nodes and familiarize yourself with how it looks when things succeed**


Load balancer?


Node failures


Garbd


IST

Online schema changes


