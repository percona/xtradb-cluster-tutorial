class percona::cluster::service ($ensure="running") {

	service {
		"mysql":
			enable  => true,
                        ensure  => $ensure,
			subscribe => File['/etc/my.cnf'],
			require => Package['MySQL-server'],
	}
}
