class percona::cluster::remove_server {
	package {
		"Percona-Server-server-55.$hardwaremodel":
	          		alias => "MySQL-server",
	          		require => Yumrepo['percona'],
			ensure => 'absent';
		"Percona-Server-client-55.$hardwaremodel":
	          		alias => "MySQL-client",
	          		require => Yumrepo['percona'],
			ensure => 'absent';
		"mysql-libs":
			ensure => "absent";
		"Percona-Server-shared-55.$hardwaremodel":
			alias => "MySQL-shared",
			require => Yumrepo['percona'],    
			ensure => 'absent'; 
	}    
	
	exec { 'remove_master_info':
			command => "rm -f /var/lib/mysql/master.info",    
			path => "/usr/bin:/usr/sbin:/bin:/sbin",
			onlyif => [
				 "test -f /var/lib/mysql/master.info"
			 ]
	}      
	
	Package["Percona-Server-server-55.$hardwaremodel"] -> Package["Percona-Server-client-55.$hardwaremodel"] -> Package["Percona-Server-shared-55.$hardwaremodel"] -> Exec['remove_master_info']
}