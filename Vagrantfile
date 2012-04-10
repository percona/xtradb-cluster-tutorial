Vagrant::Config.run do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.define :percona1 do |percona1_config|
	percona1_config.vm.box = "centos6"
	percona1_config.vm.host_name = "percona1"
	percona1_config.ssh.max_tries = 100
	#percona1_config.vm.network("192.168.70.2")
	#percona1_config.vm.boot_mode = :gui
	percona1_config.vm.customize ["modifyvm", :id, "--memory", "256"]
	percona1_config.vm.network :hostonly, "192.168.70.2"
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
	percona2_config.ssh.max_tries = 100
	#percona2_config.vm.network("192.168.70.2")
	#percona2_config.vm.boot_mode = :gui
	percona2_config.vm.customize ["modifyvm", :id, "--memory", "256"]
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
	percona3_config.vm.customize ["modifyvm", :id, "--memory", "256"]
	percona3_config.vm.provision :puppet do |percona3_puppet|
		percona3_puppet.pp_path = "/tmp/vagrant-puppet"
		percona3_puppet.manifests_path = "manifests"
		percona3_puppet.module_path = "modules"
		percona3_puppet.manifest_file = "site.pp"
		percona3_puppet.options = "--verbose"
	end
  end

end
