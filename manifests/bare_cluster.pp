node node1 {
	include percona::repository
	include percona::cluster
	include percona::toolkit	
	include misc

	Class['percona::repository'] -> Class['percona::cluster']
	Class['percona::repository'] -> Class['percona::toolkit']

}

node node2 {
	include percona::repository
	include percona::cluster
	include percona::toolkit	
	include misc

	Class['percona::repository'] -> Class['percona::cluster']
	Class['percona::repository'] -> Class['percona::toolkit']

}

node node3 {
	include percona::repository
	include percona::cluster
	include percona::toolkit	
	include misc

	Class['percona::repository'] -> Class['percona::cluster']
	Class['percona::repository'] -> Class['percona::toolkit']
	
}

