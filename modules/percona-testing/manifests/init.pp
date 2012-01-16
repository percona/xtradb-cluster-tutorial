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
            		require => [ Yumrepo['percona-testing'], Package['MySQL-client'] ],
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

class percona-testing::config ($extraipaddr=undef) {
	
	if $hostname == "percona1" {
		$joinip = " "
	} else {
		$joinip = "192.168.70.2"
	}
	file {
		"/etc/my.cnf":
			ensure  => present,
                        content => template("percona-testing/my.cnf.erb"),
			subscribe  => Network::If['eth3'],
	}
	
	exec {
		"disable-selinux":
			path    => ["/usr/bin","/bin"],
                	command => "echo 0 >/selinux/enforce",
			unless => "grep 0 /selinux/enforce",
	}

}

class percona-testing::service {

	service {
                "mysql":
                        enable  => true,
                        ensure => running,
			subscribe =>  File['/etc/my.cnf'], 
	}
}
