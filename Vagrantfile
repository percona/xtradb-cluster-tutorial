Vagrant::Config.run do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.define :percona1 do |percona1_config|
	percona1_config.vm.box = "centos6"
	percona1_config.vm.host_name = "percona1"
        percona1_config.vm.forward_port "http", 80, 8080
	percona1_config.ssh.max_tries = 100
	#percona1_config.vm.network("192.168.70.2")
	#percona1_config.vm.boot_mode = :gui
	percona1_config.vm.customize do |percona1_vm|
        	percona1_vm.memory_size = 256
    	end
	percona1_config.vm.provision :puppet do |percona1_puppet|
		percona1_puppet.pp_path = "/tmp/vagrant-puppet"
		percona1_puppet.manifests_path = "manifests"
		percona1_puppet.module_path = "modules"
		percona1_puppet.manifest_file = "site.pp"
		percona1_puppet.options = "--verbose"
	end
  end
  config.vm.define :percona2 do |percona2_config|
	percona2_config.vm.box = "centos6"
	percona2_config.vm.host_name = "percona2"
        percona2_config.vm.forward_port "http", 80, 8081
	percona2_config.ssh.max_tries = 100
	#percona2_config.vm.network("192.168.70.2")
	#percona2_config.vm.boot_mode = :gui
	percona2_config.vm.customize do |percona2_vm|
        	percona2_vm.memory_size = 256
    	end
	percona2_config.vm.provision :puppet do |percona2_puppet|
		percona2_puppet.pp_path = "/tmp/vagrant-puppet"
		percona2_puppet.manifests_path = "manifests"
		percona2_puppet.module_path = "modules"
		percona2_puppet.manifest_file = "site.pp"
		percona2_puppet.options = "--verbose"
	end
  end
  config.vm.define :percona3 do |percona3_config|
	percona3_config.vm.box = "centos6"
	percona3_config.vm.host_name = "percona3"
	percona3_config.ssh.max_tries = 100
	#percona3_config.vm.network("192.168.70.2")
	#percona3_config.vm.boot_mode = :gui
	percona3_config.vm.customize do |percona3_vm|
        	percona3_vm.memory_size = 256
    	end
	percona3_config.vm.provision :puppet do |percona3_puppet|
		percona3_puppet.pp_path = "/tmp/vagrant-puppet"
		percona3_puppet.manifests_path = "manifests"
		percona3_puppet.module_path = "modules"
		percona3_puppet.manifest_file = "site.pp"
		percona3_puppet.options = "--verbose"
	end
  end

  # config.vm.box = "base"

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  # config.vm.box_url = "http://domain.com/path/to/above.box"

  # Boot with a GUI so you can see the screen. (Default is headless)
  # config.vm.boot_mode = :gui

  # Assign this VM to a host only network IP, allowing you to access it
  # via the IP.
  # config.vm.network "33.33.33.10"

  # Forward a port from the guest to the host, which allows for outside
  # computers to access the VM, whereas host only networking does not.
  # config.vm.forward_port "http", 80, 8080

  # Share an additional folder to the guest VM. The first argument is
  # an identifier, the second is the path on the guest to mount the
  # folder, and the third is the path on the host to the actual folder.
  # config.vm.share_folder "v-data", "/vagrant_data", "../data"

  # Enable provisioning with Puppet stand alone.  Puppet manifests
  # are contained in a directory path relative to this Vagrantfile.
  # You will need to create the manifests directory and a manifest in
  # the file base.pp in the manifests_path directory.
  #
  # An example Puppet manifest to provision the message of the day:
  #
  # # group { "puppet":
  # #   ensure => "present",
  # # }
  # #
  # # File { owner => 0, group => 0, mode => 0644 }
  # #
  # # file { '/etc/motd':
  # #   content => "Welcome to your Vagrant-built virtual machine!
  # #               Managed by Puppet.\n"
  # # }
  #
  # config.vm.provision :puppet do |puppet|
  #   puppet.manifests_path = "manifests"
  #   puppet.manifest_file  = "base.pp"
  # end

  # Enable provisioning with chef solo, specifying a cookbooks path (relative
  # to this Vagrantfile), and adding some recipes and/or roles.
  #
  # config.vm.provision :chef_solo do |chef|
  #   chef.cookbooks_path = "cookbooks"
  #   chef.add_recipe "mysql"
  #   chef.add_role "web"
  #
  #   # You may also specify custom JSON attributes:
  #   chef.json.merge!({ :mysql_password => "foo" })
  # end

  # Enable provisioning with chef server, specifying the chef server URL,
  # and the path to the validation key (relative to this Vagrantfile).
  #
  # The Opscode Platform uses HTTPS. Substitute your organization for
  # ORGNAME in the URL and validation key.
  #
  # If you have your own Chef Server, use the appropriate URL, which may be
  # HTTP instead of HTTPS depending on your configuration. Also change the
  # validation key to validation.pem.
  #
  # config.vm.provision :chef_server do |chef|
  #   chef.chef_server_url = "https://api.opscode.com/organizations/ORGNAME"
  #   chef.validation_key_path = "ORGNAME-validator.pem"
  # end
  #
  # If you're using the Opscode platform, your validator client is
  # ORGNAME-validator, replacing ORGNAME with your organization name.
  #
  # IF you have your own Chef Server, the default validation client name is
  # chef-validator, unless you changed the configuration.
  #
  #   chef.validation_client_name = "ORGNAME-validator"
end
