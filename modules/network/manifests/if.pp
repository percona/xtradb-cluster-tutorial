define network::if ($ip_add = '', $proto = 'dhcp', $ip_netmask = '', $ip_network = '', $broadcast = '', $default_gw = '', $mac_addr ='') {
    file {
        "/etc/sysconfig/network-scripts/ifcfg-$name":
        	ensure  => present,
       	 	content => template("network/ifcfg-device.erb")
    }
    
    exec {
        "/etc/init.d/network restart":
		unless  =>  "/sbin/ifconfig | grep $ip_add",
    }

    if ( $default_gw != '' ) {
        file {
            	"/etc/sysconfig/network-scripts/route-$name":
            		ensure  => present,
            		content => template("network/route-device.erb")
        }

    }

}

