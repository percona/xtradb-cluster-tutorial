class xinet::service {
  service {
  	"xinetd":
	    ensure => 'running',
  		require	=> Class['xinet::packages'],
  		subscribe => File['/etc/xinetd.d/mysqlchk'];
  }  
}
