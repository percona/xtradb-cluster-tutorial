Incremental State Transfer (IST)
======================

.. contents:: 
   :backlinks: entry
   :local:

What is IST?
-------------

IST is used to avoid full SST for temporary node outages.  Note that it uses a completely separate port from SST.


Checking IST configuration
---------------------------

The IST configuration is buried in the ``wsrep_provider_options`` MySQL variable::

	node3 mysql> show variables like 'wsrep_provider_options'\G
	*************************** 1. row ***************************
	Variable_name: wsrep_provider_options
	        Value: base_host = 192.168.70.4; base_port = 4567; evs.debug_log_mask = 0x1; evs.inactive_check_period = PT0.5S; evs.inactive_timeout = PT15S; evs.info_log_mask = 0; evs.install_timeout = PT15S; evs.join_retrans_period = PT0.3S; evs.keepalive_period = PT1S; evs.max_install_timeouts = 1; evs.send_window = 4; evs.stats_report_period = PT1M; evs.suspect_timeout = PT5S; evs.use_aggregate = true; evs.user_send_window = 2; evs.version = 0; evs.view_forget_timeout = PT5M; gcache.dir = /var/lib/mysql/; gcache.keep_pages_size = 0; gcache.mem_size = 0; gcache.name = /var/lib/mysql//galera.cache; gcache.page_size = 128M; gcache.size = 128M; gcs.fc_debug = 0; gcs.fc_factor = 0.5; gcs.fc_limit = 16; gcs.fc_master_slave = NO; gcs.max_packet_size = 64500; gcs.max_throttle = 0.25; gcs.recv_q_hard_limit = 9223372036854775807; gcs.recv_q_soft_limit = 0.25; gcs.sync_donor = NO; gmcast.listen_addr = tcp://0.0.0.0:4567; gmcast.mcast_addr = ; gmcast.mcast_ttl = 1; gmcast.peer_timeout = PT3S; gmcast.time_wait = PT5S; gmcast.version = 0; ist.recv_addr = 192.168.70.4; pc.checksum = true; pc.ignore_quorum = false; pc.ignore_sb = false; pc.linger = PT2S; pc.npvo = false; pc.version = 0; protonet.backend = asio; protonet.version = 0; replicator.causal_read_timeout = PT30S; replicator.commit_order = 3
	1 row in set (0.00 sec)

Specifically, look for ``ist.recv_addr``.


Testing IST
------------

Setup pt-heartbeat again on node2::

	[root@node2 ~]# pt-heartbeat --update --database percona

We now have a write every second going into node2.  Let's stop node3 briefly and watch the error log:

screen1::

	[root@node3 ~]# tail -f /var/lib/mysql/error.log 

screen2::

	[root@node3 ~]# service mysql stop
	Shutting down MySQL (Percona Server)....... SUCCESS! 
	
	... wait a few seconds ...
	
	[root@node3 ~]# service mysql start
	Starting MySQL (Percona Server)..... SUCCESS!

Scan the error.log on node3 for references to IST.  You should see (amongst a lot of output)::

	120810 19:07:40 [Warning] WSREP: Gap in state sequence. Need state transfer.
	...
	120810 19:07:42 [Note] WSREP: Prepared IST receiver, listening at: tcp://192.168.70.4:4568
	...
	120810 19:07:43 [Note] WSREP: Receiving IST: 14 writesets, seqnos 1349-1363
	...
	120810 19:07:43 [Note] WSREP: 1 (node2): State transfer to 0 (node3) complete.

What port did IST use on node3?


What happens if IST doesn't work
--------------------------------

Unfortunately it's a bit confusing to setup IST sometimes, and it can get frustrating.  The wsrep_node_address option makes things a little easier, but before it came along, you had to configure ``ist.recv_addr`` directly in the ``wsrep_provider_options``.  Additionally, in setups with both public and private networks that you want to use for different things, you will have to still set this directly.  

Currently ``ist.recv_addr`` is set to our node's ip.  Let's simulate it being misconfigured by adding this line to our my.cnf on node3::

	wsrep_provider_options="ist.recv_addr="

Now, restart mysql on node3 (with the pt-heartbeat still running) and see what happens in the error log::

	120810 21:02:09 [Warning] WSREP: Gap in state sequence. Need state transfer.
	...
	120810 21:02:11 [Note] WSREP: Prepared IST receiver, listening at: tcp://[::1]:4568
	120810 21:02:11 [Warning] WSREP: 0 (node2): State transfer to 1 (node3) failed: -111 (Connection refused)
	120810 21:02:11 [ERROR] WSREP: gcs/src/gcs_group.c:gcs_group_handle_join_msg():712: Will never receive state. Need to abort.
	...
	120810 21:02:11 [Note] WSREP: /usr/sbin/mysqld: Terminated.

Whoops, this puppy is down!  We couldn't IST, so we barf.  Remove the ``wsrep_provider_options`` setting and restart.

I see this:: 

	120810 21:04:07 [Warning] WSREP: Failed to prepare for incremental state transfer: Local state UUID (00000000-0000-0000-0000-000000000000) does not match group state UUID (6fad8438-e25d-11e1-0800-eba2b7db20ad): 1 (Operation not permitted)
		 at galera/src/replicator_str.cpp:prepare_for_IST():439. IST will be unavailable.
	...
	120810 21:04:54 [Note] WSREP: Received SST: 6fad8438-e25d-11e1-0800-eba2b7db20ad:2654
	120810 21:04:54 [Note] WSREP: SST received: 6fad8438-e25d-11e1-0800-eba2b7db20ad:2654

Whoops, full SST!  What happens here is when WSREP aborts, it drops its state.  Even when we restart our node with a correct ``ist.recv_addr``, it has to do a full SST because the local state is: ``00000000-0000-0000-0000-000000000000``.

