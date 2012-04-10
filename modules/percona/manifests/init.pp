class percona::repository {


 $releasever = "6"
 $basearch = $hardwaremodel
 yumrepo {
        "percona":
            descr       => "Percona",
            enabled     => 1,
            baseurl     => "http://repo.percona.com/centos/$releasever/os/$basearch/",
            gpgcheck    => 0;
 }

}


class percona::common {

	package {
		"mysql-libs":
			ensure => "absent";		
		"Percona-Server-shared-compat":
			require => [ Yumrepo['percona'], Package['mysql-libs'], Package['MySQL-client'] ],
			ensure => "installed";
	}

	service {
		"mysql":
			enable  => true,
                        ensure  => running,
			require => Package['MySQL-server'],
	}
}

class percona::server {

	package {
		"Percona-Server-server-55.$hardwaremodel":
            		alias => "MySQL-server",
            		require => Yumrepo['percona'],
			ensure => "installed";
		"Percona-Server-client-55.$hardwaremodel":
            		alias => "MySQL-client",
            		require => Yumrepo['percona'],
			ensure => "installed";		
	}
}

class percona::cluster {

        package {
                "Percona-XtraDB-Cluster-server.$hardwaremodel":
                        alias => "MySQL-server",
                        require => [ Yumrepo['percona-testing'], Package['MySQL-client'] ],
                        ensure => "installed";
                "Percona-XtraDB-Cluster-client.$hardwaremodel":
                        alias => "MySQL-client",
                        require => Yumrepo['percona-testing'],
                        ensure => "installed";
                "rsync":
                        ensure => "present";
        }
}


