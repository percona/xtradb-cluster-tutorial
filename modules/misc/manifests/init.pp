class misc {
	define installCPAN () {
	  exec { "cpanLoad${title}":
	    command => "/usr/local/bin/cpanm $name",
	    path    => "/usr/bin:/usr/sbin:/bin:/sbin",
	    unless  => "perl -I.cpan -M$title -e 1",
	    timeout => 600,
	    require => [ Package['perl-ExtUtils-MakeMaker'], Exec["initCPAN"] ],
	  }
	}

	exec { "initCPAN":
	  command =>  "curl -L http://cpanmin.us | perl - --self-upgrade",
	  path    => "/usr/bin:/usr/sbin:/bin:/sbin",
	  creates  => "/usr/local/bin/cpanm",
		timeout => 300,
		user => 'root'
	}
	
	host {
		"node1":
			ensure	=> "present",
			ip 	=> "192.168.70.2";
		"node2":
			ensure	=> "present",
			ip	=> "192.168.70.3";
		"node3":
			ensure	=> "present",
			ip	=> "192.168.70.4";
	}
	service {
			'iptables': ensure => 'stopped', enable => false;
	}
	
	package {
		'screen': ensure => 'present';
		'telnet': ensure => 'present';
		'man': ensure => 'present';
		'unzip': ensure => 'present';
		'lsof': ensure => 'present';
		'perl-AnyEvent': ensure => 'installed';
		'perl-ExtUtils-MakeMaker': ensure => 'installed';
	}
	
	file {
		"/root/bin":
			owner => 'root',
			group => 'root',
			mode => 0775,
			ensure => 'directory',
	}

	exec {
			"mkdir /root/bin 2> /dev/null; wget -O myq_gadgets-latest.tgz https://github.com/jayjanssen/myq_gadgets/tarball/master && tar xvzf myq_gadgets-latest.tgz -C /root/bin --strip-components=1":
				cwd => "/tmp",
				creates => "/root/bin/myq_status",
				path => ['/bin','/usr/bin','/usr/local/bin'];
	}

	file {
		"/usr/local/bin/baseline.sh":
			owner => 'root',
			group => 'root',
			mode => 0554,
			source => "/vagrant/modules/misc/files/baseline.sh";
		"/usr/local/bin/quick_update.pl":
			owner => 'root',
			group => 'root',
			mode => 0554,
			source => "/vagrant/modules/misc/files/quick_update.pl";
	}
	
	exec {
			"wget http://downloads.mysql.com/docs/sakila-db.zip":
				cwd => "/root",
				creates => "/root/sakila-db.zip",
				path => ['/bin','/usr/bin','/usr/local/bin'];
	}
	
	installCPAN { "AnyEvent::DBI": }
}
