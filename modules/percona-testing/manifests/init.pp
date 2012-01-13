class percona-testing::repository {

 $releasever = "6"
 $basearch = $hardwaremodel
 yumrepo {
        "percona-testing":
            descr       => "Percona testing",
            enabled     => 1,
            baseurl     => "http://repo.percona.com/testing/centos/$releasever/os/$basearch/",
            gpgcheck    => 0;
 }

}

class percona-testing::packages {

	package {
		"Percona-XtraDB-Cluster-server.$hardwaremodel":
            		alias => "MySQL-server",
            		require => Yumrepo['percona-testing'],
			ensure => "installed";
		"Percona-XtraDB-Cluster-client.$hardwaremodel":
            		alias => "MySQL-client",
            		require => Yumrepo['percona-testing'],
			ensure => "installed";		
		"mysql-libs":
			ensure => "absent";		
		"rsync":	
			ensure => "present";
	}
}

class percona-testing::config {
	
	$joinip = "192.168.70.2"
	file {
		"/etc/my.cnf":
			ensure  => present,
                        content => template("percona-testing/my.cnf.erb"),
                        require => Package["MySQL-server"],
	}
}


