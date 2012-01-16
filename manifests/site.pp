class repo {
    $releasever = "5"


    yumrepo {
        
     "epel":
            descr 	=> "Epel-5",
            baseurl 	=> "http://mirror.eurid.eu/epel/5/$hardwaremodel/",
            enabled 	=> 1,
            gpgcheck 	=> 0;
     "puppetlabs":
            descr 	=> "Puppetlabs",
            baseurl 	=> "http://yum.puppetlabs.com/",
            enabled 	=> 1,
            gpgcheck 	=> 0;

        }

}

node percona1 {
	include percona::repository
	include percona-testing::repository
        include percona-testing::packages
        include percona-testing::config
	include myhosts
	network::if {
		"eth3":
			ip_add		=> "192.168.70.2",
			ip_netmask	=> "255.255.255.0",
			ip_network	=> "192.168.70.0",
			broadcast	=> "192.168.70.255",
			proto		=> "static",
	}

	Class['percona::repository'] -> Class['percona-testing::repository'] -> Class['percona-testing::packages'] -> Class['percona-testing::config']
}

node percona2 {
	include percona::repository
	include percona-testing::repository
        include percona-testing::packages
        include percona-testing::config
	include myhosts
	#include testdb::employee

	network::if {
		"eth3":
			ip_add		=> "192.168.70.3",
			ip_netmask	=> "255.255.255.0",
			ip_network	=> "192.168.70.0",
			broadcast	=> "192.168.70.255",
			proto		=> "static",
	}

	Class['percona::repository'] -> Class['percona-testing::repository'] -> Class['percona-testing::packages'] -> Class['percona-testing::config'] 
}

node percona3 {
	include percona::repository
	include percona-testing::repository
        include percona-testing::packages
        include percona-testing::config
	include myhosts

	network::if {
		"eth3":
			ip_add		=> "192.168.70.4",
			ip_netmask	=> "255.255.255.0",
			ip_network	=> "192.168.70.0",
			broadcast	=> "192.168.70.255",
			proto		=> "static",
	}

	Class['percona::repository'] -> Class['percona-testing::repository'] -> Class['percona-testing::packages'] -> Class['percona-testing::config']
}
