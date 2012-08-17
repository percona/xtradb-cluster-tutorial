class haproxy::config {
  file {
    "/etc/haproxy/haproxy.cfg":
      ensure => present,
      require => Class['haproxy::packages'],
      source => "puppet:///modules/haproxy/xtradb_cluster.cfg";
  }
}
