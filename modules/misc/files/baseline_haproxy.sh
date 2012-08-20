#!/bin/sh

service haproxy stop
mv /etc/haproxy/haproxy.cfg /tmp/haproxy.cfg-cheater
service xinetd stop
mv /etc/xinetd.d/mysqlchk /tmp/mysqlchk-cheater

mysql -u root -e "revoke all privileges on *.* from 'clustercheckuser'@'localhost'"
mysql -u root -e "drop user 'clustercheckuser'@'localhost'"
