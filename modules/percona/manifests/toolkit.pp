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
                	provider => rpm,
                	ensure   => installed,
			require  => [ Package['perl-Time-HiRes'], Package['perl-TermReadKey'], Package['perl-DBD-MySQL'] ],
                	source   => "http://www.percona.com/redir/downloads/percona-toolkit/percona-toolkit-1.0.1-1.noarch.rpm";
	}
}
