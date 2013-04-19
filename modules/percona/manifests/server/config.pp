class percona::server::config {
	file {
		"/etc/my.cnf":
			ensure  => present,
			content => template("percona/my.cnf.erb"),
	}                      
}