class percona::cluster::packages {

        package {
                "Percona-XtraDB-Cluster-server.$hardwaremodel":
                        alias => "MySQL-server",
                        require => [ Yumrepo['percona'], Package['MySQL-client'] ],
                        ensure => "installed";
                "Percona-XtraDB-Cluster-client.$hardwaremodel":
                        alias => "MySQL-client",
                        require => Yumrepo['percona'],
                        ensure => "installed";
                "rsync":
                        ensure => "present";
		"mysql-libs":
			ensure => "absent";		
		"Percona-Server-shared-compat":
			require => [ Yumrepo['percona'], Package['mysql-libs'], Package['MySQL-client'] ],
			ensure => "installed";

        }
}
