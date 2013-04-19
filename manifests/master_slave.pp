node node1 {       
	$serverid = 1
	include percona::repository
	include percona::toolkit
	include percona::server
	include misc
	
	Class['percona::repository'] -> Class['percona::server']  -> Exec['replication-user']
	Class['percona::repository'] -> Class['percona::toolkit']
		
	exec { "replication-user":
	    command => "/usr/bin/mysql -u root -e \"GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';\"",
	    unless => "/usr/bin/mysql -u root -e\"SELECT User from mysql.user WHERE User='repl';\" | /bin/grep -q repl",
	    require => [Service['mysql'], Package['MySQL-client']],
	 }
}

node node2 {   
	$serverid = 2
	include percona::repository
	include percona::toolkit
	include percona::server
	include misc
	
	Class['percona::repository'] -> Class['percona::server'] -> Exec['slave-setup']
	Class['percona::repository'] -> Class['percona::toolkit']


  exec { "slave-setup":
    command => "/usr/bin/mysql -u root -e \"CHANGE MASTER TO master_user='repl', master_host='192.168.70.2'; START SLAVE;\"",
    unless => "/usr/bin/mysql -u root -e'SHOW SLAVE STATUS' | /bin/grep -q Master",
    require => [Service[mysql], Package['MySQL-client']],
  }
}

node node3 {     
	$serverid = 3
	include percona::repository
	include percona::toolkit
	include percona::server
	include misc
	
	Class['percona::repository'] -> Class['percona::server'] -> Exec['slave-setup']
	Class['percona::repository'] -> Class['percona::toolkit']

  exec { "slave-setup":
    command => "/usr/bin/mysql -u root -e \"CHANGE MASTER TO master_user='repl', master_host='192.168.70.2'; START SLAVE;\"",
    unless => "/usr/bin/mysql -u root -e'SHOW SLAVE STATUS' | /bin/grep -q Master",
    require => [Service[mysql], Package['MySQL-client']],
  }
}

