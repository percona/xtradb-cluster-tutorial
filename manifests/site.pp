node percona1 {
	include percona::repository
	include percona-testing::repository
        include percona-testing::packages
        include percona-testing::service
	include myhosts
	$extraipaddr="192.168.70.2"
	network::if {
		"eth3":
			ip_add		=> $extraipaddr,
			ip_netmask	=> "255.255.255.0",
			ip_network	=> "192.168.70.0",
			broadcast	=> "192.168.70.255",
			proto		=> "static",
	}

	Class['percona::repository'] -> Class['percona-testing::repository'] -> Class['percona-testing::packages'] -> Class['percona-testing::config'] ->  Class['percona-testing::service']

	class {'percona-testing::config': extraipaddr => $extraipaddr}
}

node percona2 {
	include percona::repository
	include percona-testing::repository
        include percona-testing::packages
        include percona-testing::service
	include myhosts
	#include testdb::employee

	$extraipaddr="192.168.70.3"
	network::if {
		"eth3":
			ip_add		=> $extraipaddr,
			ip_netmask	=> "255.255.255.0",
			ip_network	=> "192.168.70.0",
			broadcast	=> "192.168.70.255",
			proto		=> "static",
	}

	Class['percona::repository'] -> Class['percona-testing::repository'] -> Class['percona-testing::packages'] -> Class['percona-testing::config'] ->  Class['percona-testing::service']

	class {'percona-testing::config': extraipaddr => $extraipaddr}
}

node percona3 {
	include percona::repository
	include percona-testing::repository
        include percona-testing::packages
        include percona-testing::service
	include myhosts

	$extraipaddr="192.168.70.4"
	network::if {
		"eth3":
			ip_add		=> $extraipaddr,
			ip_netmask	=> "255.255.255.0",
			ip_network	=> "192.168.70.0",
			broadcast	=> "192.168.70.255",
			proto		=> "static",
	}

	Class['percona::repository'] -> Class['percona-testing::repository'] -> Class['percona-testing::packages'] -> Class['percona-testing::config'] ->  Class['percona-testing::service']

	class {'percona-testing::config': extraipaddr => $extraipaddr}
}
