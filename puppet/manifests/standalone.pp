include percona::repository
include percona::toolkit
include percona::server
include percona::config
include percona::service

include misc
include misc::mysql_datadir
include misc::sysbench
include misc::local_percona_repo

Class['percona::repository'] -> Class['misc::local_percona_repo']
Class['misc::local_percona_repo'] -> Class['misc']

Class['misc'] -> Class['percona::server']
Class['misc'] -> Class['percona::toolkit']


Class['misc::mysql_datadir'] -> Class['percona::server']

Class['percona::repository'] -> Class['percona::server'] -> Class['percona::config'] -> Class['percona::service']

Class['percona::repository'] -> Class['percona::toolkit']
