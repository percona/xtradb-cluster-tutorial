node percona1 {
	include percona::repository
	include percona::cluster
	include percona::toolkit	
	include xinet
	include myhosts
	include haproxy

	Class['percona::repository'] -> Class['percona::cluster']
	Class['percona::repository'] -> Class['percona::toolkit']

}

node percona2 {
	include percona::repository
	include percona::cluster
	include percona::toolkit	
	include xinet
	include myhosts

	Class['percona::repository'] -> Class['percona::cluster']
	Class['percona::repository'] -> Class['percona::toolkit']

}

node percona3 {
	include percona::repository
	include percona::cluster
	include percona::toolkit	
  include xinet
	include myhosts

	Class['percona::repository'] -> Class['percona::cluster']
	Class['percona::repository'] -> Class['percona::toolkit']
	
}

