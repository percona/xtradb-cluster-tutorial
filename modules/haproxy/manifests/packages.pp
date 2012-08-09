class haproxy::packages {
  package {
  	"epel-release": ensure => installed, 
			source => 'http://mirrors.einstein.yu.edu/epel/6/i386/epel-release-6-7.noarch.rpm',
			provider => 'rpm';
  	"haproxy": ensure => installed, require => Package['epel-release'];
  }  
}

