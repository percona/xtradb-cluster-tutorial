class haproxy::config {
  file {
    "/etc/haproxy/haproxy.cfg":
      ensure => present,
      require => Class['haproxy::packages'],
      source => "/vagrant/modules/haproxy/files/xtradb_cluster.cfg";
  }
}