class percona::cluster::packages {

	package {
		"Percona-XtraDB-Cluster-server.$hardwaremodel":
			alias => "MySQL-server",
			require => [ Yumrepo['percona'], Package['MySQL-client'], Package['MySQL-shared-compat'] ],
			ensure => "installed";
		"Percona-XtraDB-Cluster-client.$hardwaremodel":
			alias => "MySQL-client",
			require => [ Yumrepo['percona'], Package['MySQL-shared-compat'] ],
			ensure => "installed";
		"rsync":
			ensure => "present";
		"mysql-libs":
			ensure => "absent";		
		"Percona-Server-shared-compat":
			alias => "MySQL-shared-compat",
			require => [ Yumrepo['percona'], Package['mysql-libs'] ],
			ensure => "installed";

	}
}
