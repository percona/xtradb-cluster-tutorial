class percona::cluster::packages {

	package {
		"Percona-XtraDB-Cluster-server.$hardwaremodel":
			require => [ Yumrepo['percona'], Package['MySQL-shared-compat'] ],
			ensure => "installed";
		"Percona-XtraDB-Cluster-client.$hardwaremodel":
			require => [ Yumrepo['percona'], Package['MySQL-shared-compat'] ],
			ensure => "installed";
		"rsync":
			ensure => "present";  
		"Percona-Server-shared-compat":
			require => [ Yumrepo['percona'], Package['mysql-libs'], Package['MySQL-client'] ],
			alias => "MySQL-shared-compat",
			ensure => "installed";
	}
}
