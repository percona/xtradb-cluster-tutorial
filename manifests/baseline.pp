node node1 {
	include percona::repository
	include percona::toolkit
	include percona::server
	include misc
	
	Class['percona::repository'] -> Class['percona::server']
	Class['percona::repository'] -> Class['percona::toolkit']
	
	file { "/etc/my.cnf":
    require => Package["MySQL-server"],
    content => "[mysqld]\nserver-id=1\nlog-bin\n",
    ensure  => "present",
    owner   => "mysql",
    group   => "mysql", 
    notify  => Service["mysql"],
  }
		
	exec { "replication-user":
	    command => "/usr/bin/mysql -u root -e \"GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';\"",
	    unless => "/usr/bin/mysql -u root -e\"SELECT User from mysql.user WHERE User='repl';\" | /bin/grep -q repl",
	    require => [Service['mysql'], Package['MySQL-client']],
	 }
}

node node2 {
	include percona::repository
	include percona::toolkit
	include percona::server
	include misc
	
	Class['percona::repository'] -> Class['percona::server']
	Class['percona::repository'] -> Class['percona::toolkit']
	
	file { "/etc/my.cnf":
    require => Package["MySQL-server"],
    content => "[mysqld]\nserver-id=2\nlog-bin\n",
    ensure  => "present",
    owner   => "mysql",
    group   => "mysql", 
    notify  => Service["mysql"],
  }

  exec { "slave-setup":
    command => "/usr/bin/mysql -u root -e \"CHANGE MASTER TO master_user='repl', master_host='192.168.70.2'; START SLAVE;\"",
    unless => "/usr/bin/mysql -u root -e'SHOW SLAVE STATUS' | /bin/grep -q Master",
    require => [Service[mysql], Package['MySQL-client']],
  }
}

node node3 {
	include percona::repository
	include percona::toolkit
	include percona::server
	include misc
	
	Class['percona::repository'] -> Class['percona::server']
	Class['percona::repository'] -> Class['percona::toolkit']
	
	file { "/etc/my.cnf":
    require => Package["MySQL-server"],
    content => "[mysqld]\nserver-id=3\nlog-bin\n",
    ensure  => "present",
    owner   => "mysql",
    group   => "mysql", 
    notify  => Service["mysql"],
  }

  exec { "slave-setup":
    command => "/usr/bin/mysql -u root -e \"CHANGE MASTER TO master_user='repl', master_host='192.168.70.2'; START SLAVE;\"",
    unless => "/usr/bin/mysql -u root -e'SHOW SLAVE STATUS' | /bin/grep -q Master",
    require => [Service[mysql], Package['MySQL-client']],
  }
}

