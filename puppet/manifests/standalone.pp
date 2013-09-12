include percona::repository
include percona::toolkit
include percona::server
include percona::config
include percona::service
include percona::client

include misc
include misc::mysql_datadir
include misc::sysbench
include misc::local_percona_repo

Class['misc::local_percona_repo'] -> Class['misc']
Class['misc::local_percona_repo'] -> Class['percona::repository']

Class['misc::mysql_datadir'] -> Class['percona::server']

Class['percona::repository'] -> Class['percona::client'] -> Class['percona::config'] -> Class['percona::server'] -> Class['percona::service']

Class['percona::repository'] -> Class['percona::client'] -> Class['percona::toolkit']
