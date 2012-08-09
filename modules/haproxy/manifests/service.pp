class haproxy::service {
  
  service {
		"haproxy":
  	  ensure => 'running',
			enable => true,
			require	=> Class['haproxy::config'],
			subscribe => File['/etc/haproxy/haproxy.cfg']
	}
	
}