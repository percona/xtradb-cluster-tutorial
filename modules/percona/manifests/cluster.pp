class percona::cluster {     
	include percona::cluster::remove_server
	include percona::cluster::packages
	include percona::cluster::config  
	include percona::cluster::bootstrap
	include percona::cluster::service    
 

	Class['percona::cluster::remove_server'] -> Class['percona::cluster::packages'] -> Class['percona::cluster::config'] -> Class['percona::cluster::bootstrap'] ->  Class['percona::cluster::service']

	
}
