#!/bin/bash

function myhelp()
{
	echo
	echo "Usage: $0 [--setup|--status-only]"
	echo
	echo " --setup        Execute CHANGE MASTER and START SLAVE"
	echo " --status-only  Just print out relavent SHOW SLAVE STATUS"
	echo
	echo "This script will setup master/slave relationship for multiple clusters managed"
	echo "by a single Vagrantfile. Script assumes nodes are named node1 (master)"
	echo "and node2/node3 (slaves) suffixed with '-T#' indicating team number"
	echo 
	exit 1
}

function check_params()
{
	if [ "$1" != "--setup" ] && [ "$1" != "--status-only" ]; then
		echo; echo "$1 : Not recognized"
		myhelp
	fi
}

if [ ! -f "ssh-config.txt" ]; then
	echo "You need to export an 'ssh-config.txt' file first."
	echo "Example: vagrant ssh-config >ssh-config.txt"
	echo
	exit 1
fi

if [ "$#" -ne 1 ]; then
	myhelp
fi

check_params $1

grep node1-T1 ssh-config.txt 2>&1 >/dev/null
if [ "$?" -eq "1" ]; then
	echo; echo "Could not locate node1-T1 in your ssh-config.txt"
	myhelp
fi

# Figure out the number of teams by checking hostnames
numteams=$(grep -o "T[0-9]\+" ssh-config.txt | cut -dT -f2 | sort -n | tail -1)

createUser="mysql -e \"GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%' IDENTIFIED BY 'repl'\""

for i in `seq 1 ${numteams}`; do
  master="node1-T${i}"
  slaves=("node2-T${i}" "node3-T${i}")
  
  status=$(ssh -F ssh-config.txt $master "mysql -Be 'SHOW MASTER STATUS' | tail -n 1; ${createUser}")
  binlogfile=$(echo $status | awk '{print $1}')
  binlogpos=$(echo $status | awk '{print $2}')
  
  changemaster="CHANGE MASTER TO MASTER_HOST='${master}', MASTER_USER='repl', MASTER_PASSWORD='repl', MASTER_LOG_FILE='${binlogfile}', MASTER_LOG_POS=${binlogpos};"
  
  for j in ${slaves[@]}; do
	if [ "$1" != "--status-only" ]; then
  		ssh -F ssh-config.txt $j "mysql -e \"$changemaster\"; mysql -e \"start slave; select sleep(1); show slave status\G\"" | grep -i "^Slave_\|^Master_Host\|^Seconds_"
  	else
  		ssh -F ssh-config.txt $j "mysql -e \"show slave status\G\"" | grep -i "_Running\|Master_Host\|Seconds_"
  	fi
  	echo
  done
  
  echo
  echo "==== Completed $master and its slaves ===="
  echo
done