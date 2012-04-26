class percona::cluster::config {

        if $hostname == "percona1" {
              # Percona1 can't join itself, so if this node gets wacked out, it tries to talk to percona2
                # $joinip = "192.168.70.3"
                $joinip = " "
        } else {
            # All other nodes join percona1
                $joinip = "192.168.70.2"
        }
        file {
                "/etc/my.cnf":
                        ensure  => present,
                        content => template("percona/cluster/my.cnf.erb"),
        }

        exec {
                "disable-selinux":
                        path    => ["/usr/bin","/bin"],
                        command => "echo 0 >/selinux/enforce",
                        unless => "grep 0 /selinux/enforce",
        }

}
