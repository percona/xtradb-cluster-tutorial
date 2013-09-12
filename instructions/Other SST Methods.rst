Other SST Methods
======================

.. contents:: 
   :backlinks: entry
   :local:

rsync
------

The first alternative SST method is rsync.  Let's modify the my.cnf on node3 like this::

	# wsrep_sst_method				= xtrabackup
	# wsrep_sst_auth                  = sst:secret
	wsrep_sst_method                = rsync
	wsrep_sst_donor                = node2

Now, we can stop mysql, delete the grastate.dat (to force an SST), and restart mysql::

	service mysql stop
	rm /var/lib/mysql/grastate.dat
	service mysql start

- What happens to replication node2 during the donation?
- Does "select count(*) from test.sbtest1" work on node2?  Should it?
- How long does the SST take relative to an xtrabackup?


mysqldump
-----------

Now change your SST method via the my.cnf on node3::

	# wsrep_sst_method                = xtrabackup
	wsrep_sst_method                = mysqldump
	wsrep_sst_auth                  = sst:secret
	wsrep_sst_donor                = node2

Stop, remove the grastate.dat and restart mysql just like before.

- What happens to replication node2 during the donation?
- Does "select count(*) from test.sbtest1" work on node2?  Should it?
- How long does the SST take relative to an xtrabackup and an rsyncs?

Customizing SST scripts
-------------------------