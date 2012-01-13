class myhosts {
	host {
		"percona1":
			ensure	=> "present",
			ip 	=> "192.168.70.2";
		"percona2":
			ensure	=> "present",
			ip	=> "192.168.70.3";
		"percona3":
			ensure	=> "present",
			ip	=> "192.168.70.4";
		"percona4":
			ensure	=> "present",
			ip	=> "192.168.70.5";
	}
}
