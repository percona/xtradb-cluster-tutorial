class percona::cluster::service ($ensure="running") {

	service {
		"mysql":
			enable  => true,
			ensure  => $ensure,
			require => [File['/etc/my.cnf'], Package['MySQL-server']]
	}
}
