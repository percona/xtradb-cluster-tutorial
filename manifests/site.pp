node percona1 {
	include percona::repository
	include percona::cluster
	include xinet
	include myhosts
	include haproxy

	Class['percona::repository'] -> Class['percona::cluster']


}

node percona2 {
	include percona::repository
	include percona::cluster
	include xinet
	include myhosts

	Class['percona::repository'] -> Class['percona::cluster']

}

node percona3 {
	include percona::repository
	include percona::cluster
  include xinet
	include myhosts

	Class['percona::repository'] -> Class['percona::cluster']
}

