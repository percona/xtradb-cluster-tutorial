class percona::xtrabackup {

	package {
		"xtrabackup.$hardwaremodel":
			alias   => "xtrabackup",
			require => [ Yumrepo['percona'], Package['Percona-Server-shared-compat'] ],
			ensure  => installed;
	}
}
