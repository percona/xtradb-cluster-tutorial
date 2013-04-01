SSL Replication 
======================

.. contents:: 
   :backlinks: entry
   :local:


Introduction
--------------------------

By default Galera uses unencrypted transport between nodes (like standard MySQL replication).  But, it is possible to configure SSL replication.  


Create OpenSSL Key
------------------------

Use the openssl command on node1 to generate a key and cert that will be valid for a long time::

	[root@node1 ssl]# openssl req -new -x509 -days 365000 -nodes -keyout key.pem -out cert.pem
	Generating a 2048 bit RSA private key
	..............+++
	................................................................+++
	writing new private key to 'key.pem'
	-----
	You are about to be asked to enter information that will be incorporated
	into your certificate request.
	What you are about to enter is what is called a Distinguished Name or a DN.
	There are quite a few fields but you can leave some blank
	For some fields there will be a default value,
	If you enter '.', the field will be left blank.
	-----
	Country Name (2 letter code) [XX]:
	State or Province Name (full name) []:
	Locality Name (eg, city) [Default City]:
	Organization Name (eg, company) [Default Company Ltd]:
	Organizational Unit Name (eg, section) []:
	Common Name (eg, your name or your server's hostname) []:
	
	[root@node1 ssl]# ls -lah
	total 16K
	drwxr-xr-x. 2 root root 4.0K Apr  1 12:08 .
	dr-xr-x---. 4 root root 4.0K Apr  1 12:03 ..
	-rw-r--r--. 1 root root 1.2K Apr  1 12:08 cert.pem
	-rw-r--r--. 1 root root 1.7K Apr  1 12:08 key.pem

Copy these files from node1 to the other nodes.  In a production environment you should be careful to copy them securely, but for us netcat is fine::

	[root@node2 ssl]# nc -dl 9999 | tar xvz
	
	[root@node1 ssl]# tar cvz * | nc 192.168.70.4 9999
	cert.pem
	key.pem
	
	# node2 outputs::
	cert.pem
	key.pem


Put these files into /etc/mysql::

	[root@node1 ssl]# mkdir /etc/mysql
	[root@node1 ssl]# mv *.pem /etc/mysql
	[root@node1 ssl]# cd /etc/mysql
	[root@node1 mysql]# chown -R mysql.mysql /etc/mysql/
	[root@node1 mysql]# chmod -R o-rwx /etc/mysql/
	[root@node1 mysql]# ls -lah
	total 16K
	drwxr-x---.  2 mysql mysql 4.0K Apr  1 12:12 .
	drwxr-xr-x. 60 root  root  4.0K Apr  1 12:12 ..
	-rw-r-----.  1 mysql mysql 1.2K Apr  1 12:08 cert.pem
	-rw-r-----.  1 mysql mysql 1.7K Apr  1 12:08 key.pem


Configure galera to use these SSL files
-----------------------------------------

Add this to your my.cnf on each node:

	wsrep_provider_options          = "socket.ssl_cert=/etc/mysql/cert.pem; socket.ssl_key=/etc/mysql/key.pem"

There is no way to rolling restart the cluster when enabling SSL.  Shutdown each node cleanly.  Then restart the cluster one node at a time, bootstrapping the first node you startup::

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

Start the cluster again (bootstrap the first node) with the SSL configuration in place.  There should be no need for SST::

	[root@node1 mysql]# service mysql start --wsrep_cluster_address=gcomm://
	[root@node2 mysql]# service mysql start
	[root@node3 mysql]# service mysql start

Compression and SSL Ciphers
-----------------------------------------

These settings can be tweaked with the::

	socket.ssl_cipher
	socket.ssl_compression

Settings in wsrep_provider_options.  Feel free to tinker. 

http://www.codership.com/wiki/doku.php?id=galera_parameters_0.8


