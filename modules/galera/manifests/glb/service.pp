class galera::glb::service ($glb_list_backend, $glb_ip_control, $glb_ip_loadbalancer, $glb_threads) {

	exec {
		"run_glb":
			command	=> "glbd --daemon --threads $glb_threads --control $glb_ip_control:4445 $glb_ip_loadbalancer:3306 $glb_list_backend",
			path	=> ["/usr/sbin", "/bin" ],
			require	=> Class['Galera::Glb::Packages'],
			unless	=> "ps ax | grep [g]lbd 2> /dev/null",	
	}
}
