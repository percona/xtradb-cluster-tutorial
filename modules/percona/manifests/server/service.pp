class percona::server::service ($ensure="running") {


	service {
		"mysql":
			enable  => true,
                        ensure  => $ensure,
			require => Package['MySQL-server'],
	}

}
