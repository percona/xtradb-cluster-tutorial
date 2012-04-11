class percona::repository {


 $releasever = "6"
 $basearch = $hardwaremodel
 yumrepo {
        "percona":
            descr       => "Percona",
            enabled     => 1,
            baseurl     => "http://repo.percona.com/centos/$releasever/os/$basearch/",
            gpgcheck    => 0;
 }

}
