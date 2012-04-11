class percona::cluster::config {

        if $hostname == "percona1" {
                $joinip = " "
        } else {
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
