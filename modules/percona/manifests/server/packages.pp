class percona::server::packages {

	package {
		"Percona-Server-server-55.$hardwaremodel":
            		alias => "MySQL-server",
            		require => Yumrepo['percona'],
			ensure => "installed";
		"Percona-Server-client-55.$hardwaremodel":
            		alias => "MySQL-client",
            		require => Yumrepo['percona'],
			ensure => "installed";		
		"mysql-libs":
			ensure => "absent";		
		"Percona-Server-shared-compat":
			require => [ Yumrepo['percona'], Package['mysql-libs'], Package['MySQL-client'] ],
			ensure => "installed";
	}
}
