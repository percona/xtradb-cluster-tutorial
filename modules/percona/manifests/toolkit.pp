class percona::toolkit {

	package {
		"perl-Time-HiRes":
			ensure  => installed;
		"perl-TermReadKey":
			ensure  => installed;
		"perl-DBD-MySQL":
			ensure  => installed,
			require => Package['Percona-Server-shared-compat'];
    "percona-toolkit":
    	ensure   => installed,
			require  => [ Package['perl-Time-HiRes'], Package['perl-TermReadKey'], Package['perl-DBD-MySQL'] ];
		}
}
