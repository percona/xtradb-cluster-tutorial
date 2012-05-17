class haproxy::service {
  
  service {
		"haproxy":
  	  ensure => 'running',
			require	=> Class['haproxy::config'],
			subscribe => File['/etc/haproxy/haproxy.cfg']
	}
	
}