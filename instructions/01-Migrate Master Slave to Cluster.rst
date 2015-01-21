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


Start up the application
----------------------------------

We will use sysbench to simulate application load on our master node, node1::

  [root@node1 ~]# run_sysbench_update_oltp.sh

The sysbench run should output the current transaction rate and response time every second.  

**Run sysbench oltp on node1, confirm replication is working to the slaves**


Sanity Check the Environment
------------------------------------------------------------------------

We can sanity check our setup in two ways.  First, simply run pt-table-checksum on the master::

	[root@node1 ~]# pt-table-checksum --user=test --password=test

**Run pt-table-checksum from node1**

This will output all the tables being checked. The 'test' mysql user is setup so it can connect to all the nodes from the master, and it will correctly report differences on the slave(s).  

**Query the percona.checksums table on node2 and node3 and look for any differences**

Secondly, we can check replication. Nodes 2 and 3 are slaves to node1, and we can certainly check ``SHOW SLAVE STATUS\G`` to see if there are any replication problems.  

**Check SHOW SLAVE STATUS on nodes 2 and 3 to see if replication is working**

A more programmatic way to check replication lag is to use pt-heartbeat::

	[root@node1 ~]# pt-heartbeat --update --database percona --create-table --daemonize

We can check the heartbeat by querying the percona.heartbeat table, or by running the pt-heartbeat command on node2 and node3::

	[root@node2 mysql]# pt-heartbeat --monitor --database percona --master-server-id=1
	0.00s [  0.00s,  0.00s,  0.00s ]
	0.00s [  0.00s,  0.00s,  0.00s ]
	0.00s [  0.00s,  0.00s,  0.00s ]
	0.00s [  0.00s,  0.00s,  0.00s ]
	0.00s [  0.00s,  0.00s,  0.00s ]
	0.00s [  0.00s,  0.00s,  0.00s ]

**Run pt-heartbeat on node1 and check the lag on node2 and node3**

Try a few more experiments with the heartbeat::

- Stop the heartbeat tool on node1 and see how that affects the output on node2 and node3
- Stop replication on node3 (STOP SLAVE) for a while, then restart it.  How long does the heartbeat take to catch up?


Update one slave to PXC
------------------------

Now that we have a verified working Master/Slave environment with real load, we want to take one of the slaves (we'll start with node3) and convert that to the PXC software.  Each Percona Server package has a PXC equivalent, and PXC is a drop in replacement for Percona server, so we'll simply remove Percona Server and install PXC::

	[root@node3 ~]# systemctl stop mysql
  [root@node3 ~]# yum swap -- remove Percona-Server-shared-56 Percona-Server-server-56 -- install Percona-XtraDB-Cluster-shared-56 Percona-XtraDB-Cluster-server-56
	[root@node3 ~]# systemctl start mysql
	[root@node3 ~]# mysql -e "show slave status\G"

MySQL should startup correctly, and replication should resume from the master.   

Note that dependency fights with Yum and RPM are not uncommon here.  

**Remove the Percona Server package and replace it with PXC.  Restart mysql and verify the slave still works properly**


Configure node3 as a 1 node cluster
------------------------------------

At this point node3 is running PXC, but none of the cluster configuration has been done.  Therefore, it is acting simply as a regular MySQL slave.  We will now add Galera configuration to the node to register it as a cluster (of 1).  

**Configure node3 with the appropriate wsrep settings in /etc/my.cnf and restart mysql**

Make the mysqld section of node3:/etc/my.cnf look like this::

	[mysqld]
	server-id                       = 3
	binlog_format                   = ROW

	# galera settings
	wsrep_provider                  = /usr/lib64/libgalera_smm.so

	wsrep_cluster_name              = mycluster
	wsrep_cluster_address           = gcomm://192.168.70.2,192.168.70.3,192.168.70.4
	wsrep_node_name                 = node3
	wsrep_node_address              = 192.168.70.4

	wsrep_sst_method                = xtrabackup-v2
	wsrep_sst_auth		            = sst:secret

	# innodb settings for galera
	innodb_autoinc_lock_mode        = 2
	innodb_locks_unsafe_for_binlog  = ON

	# leave existing Innodb settings

Note that the node_address may be different if you are using AWS.  It should be the local ip of the node being used for Galera replication.

Now restart mysql on node3::

	[root@node3 ~]# systemctl restart mysql

- Does MySQL restart?  
- What's in the error log?
- What could be going wrong?

The first node started in a PXC cluster must be 'bootstrapped'. If a node is started without being bootstrapped and it cannot find an existing cluster to connect to, it will hang waiting for other nodes to appear.  You have to kill -9 this mysqld and start again. The simple way to bootstrap with systemd is to do this::

  [root@node3 ~]# systemctl start mysql@bootstrap
	

**Get node3 started, there may be hurdles to overcome**

Check cluster state
--------------------

We've configured node3 as our initial cluster node.  What's more is that we will use node3 as the bridge between the current master and the cluster.  We want to ensure it is configured properly before going further.  

To check the cluster state, we will use the ``myq_status`` tool.  Execute::

	[root@node3 ~]# myq_status wsrep

This tool shows us information about the node state.  Try to determine:

- How many nodes are in the cluster?
- Is the cluster "Primary"?
- Are cluster replication events being generated?

**Run myq_status on node3 and try to answer the above questions before continuing**

You might notice that in spite of replication from node1 flowing into node3, the PXC cluster is not generating any replication events (no Ops or Bytes registering as replicating)!  

::

	[root@node3 ~]# myq_status wsrep
	mycluster / node3 / Galera 3.3(r171)
	Wsrep    Cluster  Node     Queue   Ops     Bytes     Flow      Conflct  PApply        Commit
	    time P cnf  #  cmt sta  Up  Dn  Up  Dn   Up   Dn  p_ms snt lcf bfa dst oooe oool wind
	15:29:23 P   1  1 Sync T/T   0   0   0   2    0  124     0   0   0   0   0    0    0    0
	15:29:24 P   1  1 Sync T/T   0   0   0   0    0    0     0   0   0   0   0    0    0    0
	15:29:25 P   1  1 Sync T/T   0   0   0   0    0    0     0   0   0   0   0    0    0    0
	15:29:26 P   1  1 Sync T/T   0   0   0   0    0    0     0   0   0   0   0    0    0    0


It turns out we have a misconfiguration in our cluster that we need to address.  

**Try to figure out what we might need to add to the my.cnf to allow incoming standard MySQL replication events be replicated to throughout the cluster**

We need to configure ``log-slave-updates`` on node3 to treat incoming mysql replication traffic as data that should be written to the cluster.  Add this line to node3's my.cnf and restart mysql::

	log-slave-updates

**Reconfigure node3 and restart mysqld**

Restarting a bootstrapped node with systemd is weird:

	[root@node3 ~]# systemctl restart mysql@bootstrap

What do you see in ``myq_status`` now?

::

	[root@node3 ~]# myq_status wsrep
	mycluster / node3 / Galera 3.3(r171)
	Wsrep    Cluster  Node     Queue   Ops     Bytes     Flow      Conflct  PApply        Commit
	    time P cnf  #  cmt sta  Up  Dn  Up  Dn   Up   Dn  p_ms snt lcf bfa dst oooe oool wind
	15:30:36 P   1  1 Sync T/T   0   0 426   5 658K  148     0   0   0   0   1    0    0    1
	15:30:37 P   1  1 Sync T/T   0   0  12   0  18K    0     0   0   0   0   1    0    0    1
	15:30:38 P   1  1 Sync T/T   0   0   7   0  11K    0     0   0   0   0   1    0    0    1
	15:30:39 P   1  1 Sync T/T   0   0  17   0  27K    0     0   0   0   0   1    0    0    1
	15:30:40 P   1  1 Sync T/T   0   0   8   0  12K    0     0   0   0   0   1    0    0    1



At this point, we can see that we have a 1 node cluster that is 'Primary' ('P') column, and that replication events are being uploaded ('Up') to the cluster, even though there are no other cluster nodes yet.  This indicates that node3 is acting as a relay for async replication into the cluster.


Preparing node2 to join the cluster
----------------------------------

At this point we're ready to move node2 into the cluster.  Node2 is also a slave of node1, and we first want to disable that replication::

	node2> stop slave;
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

	wsrep_sst_method                = xtrabackup-v2
	wsrep_sst_auth		            = sst:secret

	# innodb settings for galera
	innodb_autoinc_lock_mode         =  2
	innodb_locks_unsafe_for_binlog  = ON
	

wsrep_node_name
	By convention, simply the short hostname of the node.  This just needs to be unique across all nodes in the cluster.

wsrep_node_address
	The IP address we're using for all Galera work.  In our case this is eth1, but it could be your primary eth0 address in a normal environment.

wsrep_cluster_address
	Describes how this node needs to connect to the cluster.  Note this contains the ips of all 3 of our nodes.  Eventually we will need to set this on all the nodes, but for now it's sufficient to set it here.  Note that this setting does *not* determine cluster membership.  It simply tells the node where it might find running cluster nodes.

	Also note that we set this to 'gcomm://' on node3 when we first started the cluster.  This option tells a node it is ok for it to form a new cluster by itself.  If this is not present, then any node trying to restart without finding another already running cluster node will fail.  This process is called *bootstrapping* the cluster.

wsrep_sst_auth
	Note we are setting this to use a specific SST user.  If this is not set it defaults to the root user with no password.

**Do NOT restart mysql on node3 yet**


Trying to get node2 joined (and failing)
-----------------------------------------

So, it seems we're ready to restart node2.  When we restart mysql there's a lot of things that will happen, and it will be worth having windows open watching some things.  They include:

- myq_status' wsrep report on node3
- /var/lib/mysql/error.log on both node3 and node2
- the output of 'ps axf' on node3 and node2 while node2 is trying to start

Now, let's restart mysql on node2 and see what happens::

	[root@node2 ~]# systemctl restart mysql

- Does the init script report a successful start?
- What seems to happen to node3's state?
- Does node2's mysql start?  Does it keep running?

**Restart mysql on node2 and try to answer the above questions.  MySQL should ultimately fail, but you should be able to repeat the restart a few times so you can see what's going on**

Node2 is not able to join the cluster for some reason.  To figure out why, we need to take a slight tangent.


A tangent to discuss SST
--------------------------------

When a new node joins a cluster, it receives a state snapshot transfer (SST) from an existing member of the cluster.  In our case, node3 is the only valid node in the cluster, so it will be the *donor* node, and node2 will be our *joiner* node.  

If you watch ``myq_status`` you should see node3 enter the *donor* state for a bit, and then go back to *Sync*.  You should also see the node count go from 1 to 2 and back to 1 (see the *#* column).

An SST is actually just a full backup.  In our case, we configured our ``wsrep_sst_method`` to be xtrabackup-v2.  This is taking a hot backup of node3 and streaming it to node2.  

In our case, this is failing for some reason. If you watched the process list ('px axf') on node3, you might have seen xtrabackup running.  When a donor node runs xtrabackup, a log is generated in /var/lib/mysql/innobackup.backup.log.  We should check here for an indication of what happened. 

**Check the donor node's (node3) xtrabackup SST log file to see if there are any errors**

If I check the innobackup.backup.log on node3 again, I see this error::

	ERROR: Failed to connect to MySQL server: DBI connect(';mysql_read_default_file=/etc/my.cnf;mysql_read_default_group=xtrabackup;mysql_socket=/var/lib/mysql/mysql.sock','sst',...) failed: Access denied for user 'sst'@'localhost' (using password: YES) at /usr//bin/innobackupex line 1601


Xtrabackup requires `mysql access <http://www.percona.com/doc/percona-xtrabackup/innobackupex/privileges.html#permissions-and-privileges-needed>`_ to take it's backup, but we haven't configured that.

We first need to setup a user on node3::

	node3> GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'sst'@'localhost' IDENTIFIED BY 'secret';


**Create an SST user on node3 with the appropriate privileges, ensure the right wsrep_sst_auth setting is in your my.cnf files and retry mysql on node2 again**

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

Is data from node1 flowing to both nodes in the cluster?


Taking stock of what we've achieved
------------------------------------

So, to take stock of where we are.  We have our existing production database on node1 taking writes from our (simulated) application.  These writes are flowing via standard async MySQL replication from node1 (master) to node3 (slave).  node3 and node2 are linked by the cluster replication.  

At this point in a production migration, we'd likely want to pause and make sure we were ready to migrate.  This might include:

- Verifying the data on our production master matches our new cluster
- Checking to ensure mysql replication can keep up until we migrate
- Tuning the cluster
- QA and testing the cluster

Some of these are more involved than others, but let's do a few.

Finishing the migration
-------------------------

Let's suppose we have done all our testing and validation.  How should we migrate our application to the cluster?

Here's some possible steps:

#. Ensure replication is caught up on the cluster (And is continuing to keep up)
#. Revalidate the data is identical on the current master and the cluster with pt-table-checksum
#. Shutdown the application pointing to node1
#. Shutdown (and RESET) replication on node3 from node1
#. Startup the application pointing to node3
#. Rebuild node1 as another member of the cluster

- Do these steps make sense?
- What else might you want to do?
- How can you minimize the downtime?
- Is there any rollback?


Joining node1 to the cluster without SST
-----------------------------------------

Our SST is not particularly expensive, but we have a few facts in this setup that can make it possible to avoid SST when joining node1 to the rest of the cluster.  

#. The application only writes to node1 in this case and we have to stop the appplication to upgrade node1 (though in real prod cases, we might do something else).
#. We know node1 and the cluster are in sync.

If we simply take application downtime and then synchronize node1 to the cluster, we can do so in a tricky way to avoid SST.  

#. Shut down sysbench on node1 and verify the nodes are caught up
#. Update the packages and config on node1 to PXC
#. Before starting mysql on node1, temporarily set wsrep_sst_method=skip in node1's my.cnf
#. Start mysql on node1 and check for SST

**Follow the above steps and get node1 synchronized to the rest of the cluster**
