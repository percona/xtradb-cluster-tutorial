class haproxy {
  
  include haproxy::packages
  include haproxy::config
  include haproxy::service
	
  Class['haproxy::packages'] -> Class['haproxy::config'] -> Class['haproxy::service']
  
}
