# This has to be a separate type to enable collecting
Puppet::Type.newtype(:mysql_user) do
  @doc = "Manage a database user."
  ensurable
  newparam(:name) do
    desc "The name of the user. This uses the 'username@hostname' form."

    validate do |value|
      if value.split('@').first.size > 16
        raise ArgumentError,
              "MySQL usernames are limited to a maximum of 16 characters"
      else
        super
      end
    end
  end

  newproperty(:password_hash) do
    desc "The password hash of the user. Use mysql_password() for creating such a hash."
  end
end

