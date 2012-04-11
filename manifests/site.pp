node percona1 {
	include percona::repository
	include percona::cluster::packages
	include percona::cluster::service
	include myhosts

	Class['percona::repository'] -> Class['percona::cluster::packages'] -> Class['percona::cluster::config'] ->  Class['percona::cluster::service']

	class {'percona::cluster::config': extraipaddr => $ipaddress_eth1 }
}

node percona2 {
	include percona::repository
	include percona::cluster::packages
	include percona::cluster::service
	include myhosts

	Class['percona::repository'] -> Class['percona::cluster::packages'] -> Class['percona::cluster::config'] ->  Class['percona::cluster::service']

	class {'percona::cluster::config': extraipaddr => $ipaddress_eth1 }
}

node percona3 {
	include percona::repository
	include percona::cluster::packages
	include percona::cluster::service
	include myhosts

	Class['percona::repository'] -> Class['percona::cluster::packages'] -> Class['percona::cluster::config'] ->  Class['percona::cluster::service']

	class {'percona::cluster::config': extraipaddr => $ipaddress_eth1 }
}

