class xinet {
  
  include xinet::packages
  include xinet::config
  include xinet::service
	
  Class['xinet::packages'] -> Class['xinet::config'] -> Class['xinet::service']
  
}
