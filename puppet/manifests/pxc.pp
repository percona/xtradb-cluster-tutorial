include percona::repository
include percona::toolkit
include percona::cluster

include misc
include misc::mysql_datadir
include misc::sysbench
include misc::local_percona_repo

Class['percona::repository'] -> Class['misc::local_percona_repo']
Class['misc::local_percona_repo'] -> Class['misc']

Class['misc'] -> Class['percona::cluster']
Class['misc'] -> Class['percona::toolkit']

Class['misc::mysql_datadir'] -> Class['percona::cluster']

Class['percona::repository'] -> Class['percona::cluster']
Class['percona::repository'] -> Class['percona::toolkit']
