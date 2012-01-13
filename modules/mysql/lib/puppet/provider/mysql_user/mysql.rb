require 'puppet/provider/package'

Puppet::Type.type(:mysql_user).provide(:mysql,
		# T'is funny business, this code is quite generic
		:parent => Puppet::Provider::Package) do

	desc "Use mysql as database."
	commands :mysql => '/usr/bin/mysql'
	commands :mysqladmin => '/usr/bin/mysqladmin'

	# retrieve the current set of mysql users
	def self.instances
		users = []

		cmd = "#{command(:mysql)} mysql -NBe 'select concat(user, \"@\", host), password from user'"
		execpipe(cmd) do |process|
			process.each do |line|
				users << new( query_line_to_hash(line) )
			end
		end
		return users
	end

	def self.query_line_to_hash(line)
		fields = line.chomp.split(/\t/)
		{
			:name => fields[0],
			:password_hash => fields[1],
			:ensure => :present
		}
	end

	def mysql_flush 
		mysqladmin "flush-privileges"
	end

	def query
		result = {}

		cmd = "#{command(:mysql)} -NBe 'select concat(user, \"@\", host), password from user where concat(user, \"@\", host) = \"%s\"'" % @resource[:name]
		execpipe(cmd) do |process|
			process.each do |line|
				unless result.empty?
					raise Puppet::Error,
						"Got multiple results for user '%s'" % @resource[:name]
				end
				result = query_line_to_hash(line)
			end
		end
		result
	end

	def create
		mysql "mysql", "-e", "create user '%s' identified by PASSWORD '%s'" % [ @resource[:name].sub("@", "'@'"), @resource.should(:password_hash) ]
		mysql_flush
	end

	def destroy
		mysql "mysql", "-e", "drop user '%s'" % @resource[:name].sub("@", "'@'")
		mysql_flush
	end

	def exists?
		not mysql("mysql", "-NBe", "select '1' from user where CONCAT(user, '@', host) = '%s'" % @resource[:name]).empty?
	end

	def password_hash
		@property_hash[:password_hash]
	end

	def password_hash=(string)
		mysql "mysql", "-e", "SET PASSWORD FOR '%s' = '%s'" % [ @resource[:name].sub("@", "'@'"), string ]
		mysql_flush
	end
end

