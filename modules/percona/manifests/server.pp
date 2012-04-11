class percona::server ($ensure="running") {
	include percona::server::packages
	include percona::server::service

	Class['percona::server::packages'] ->  Class['percona::server::service']	
}
