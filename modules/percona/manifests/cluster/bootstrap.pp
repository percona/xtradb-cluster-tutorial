class percona::cluster::bootstrap ($ensure="running") {

	exec { 'bootstrap_node1':
			command => "/etc/init.d/mysql start --wsrep_cluster_address=gcomm://", 
			path => "/usr/bin:/usr/sbin:/bin:/sbin",
			onlyif => [
				 "test `hostname` = 'node1' && service mysql status || service mysql start || true"
			 ]
	}
	
	exec { 'xtrabackup_sst_grant_node1':
    command => "/usr/bin/mysql -u root -e \"GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'sst'@'localhost' IDENTIFIED BY 'secret'\"",  
		path => "/usr/bin:/usr/sbin:/bin:/sbin",
    unless => "/usr/bin/mysql -u root -e\"SELECT User from mysql.user WHERE User='sst';\" | /bin/grep -q sst",
		onlyif => [
			"test `hostname` = 'node1'"
		]
	}  
	
	Exec['bootstrap_node1'] -> Exec['xtrabackup_sst_grant_node1']
}
