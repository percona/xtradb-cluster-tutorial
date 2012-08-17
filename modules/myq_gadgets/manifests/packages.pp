class myq_gadgets::packages {
  
   file {
		"/tmp/myq_gadgets-0.1-1.el6.noarch.rpm":
			ensure => present,
      			source => "puppet:///modules/myq_gadgets/myq_gadgets-1.0-1.el6.noarch.rpm",
   }

   package {
                "myq_gadgets":
                        provider => rpm,
                        ensure   => installed,
                        source   => "/tmp/myq_gadgets-1.0-1.el6.noarch.rpm",
			require  => File["/tmp/myq_gadgets-1.0-1.el6.noarch.rpm"],
   }
}
