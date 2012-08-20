#!/bin/sh

service mysql stop
mv /etc/my.cnf /etc/my.cnf.cheater
rm -rf /var/lib/mysql
mysql_install_db --user=mysql
chmod go+rx /var/lib/mysql