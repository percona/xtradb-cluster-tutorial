class galera::glb ( $glb_list_backend=undef, $glb_ip_control="127.0.0.1", $glb_ip_loadbalancer="127.0.0.1", $glb_threads=6 ) {
	include galera::glb::packages

	class { 'galera::glb::service':
			glb_list_backend    => "$glb_list_backend",
			glb_ip_control 	    => "$glb_ip_control",
			glb_ip_loadbalancer => "$glb_ip_loadbalancer",
			glb_threads	    => "$glb_threads"
	}
}	
