class xinet::config {
  file {
    "/etc/xinetd.d/mysqlchk":
      ensure => present,
      owner => root, group => root,
      require => [Class['xinet::packages'], Class['percona::cluster::config']],
      source => "/vagrant/modules/xinet/files/mysqlchk";
  }
  
  mysql::rights { "clustercheck":
    user     => "clustercheckuser",
    password => "clustercheckpassword!",
    database => "mysql",
    priv    => ["process_priv"],
    require => Class['percona::cluster::service']
  }
}