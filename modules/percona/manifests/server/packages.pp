class percona::server::packages ($ensure="installed") {

	package {
		"Percona-Server-server-55.$hardwaremodel":
            		alias => "MySQL-server",
            		require => Yumrepo['percona'],
			ensure => $ensure;
		"Percona-Server-client-55.$hardwaremodel":
            		alias => "MySQL-client",
            		require => Yumrepo['percona'],
			ensure => $ensure;
		"mysql-libs":
			ensure => "absent";
		"Percona-Server-shared-55.$hardwaremodel":
			alias => "MySQL-shared",
			require => Yumrepo['percona'],    
			ensure => $ensure; 
		"Percona-Server-shared-compat":
			require => [ Yumrepo['percona'], Package['mysql-libs'], Package['MySQL-client'] ],
			alias => "MySQL-shared-compat",
			ensure => "installed";
	}     

}
