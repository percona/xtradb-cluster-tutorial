# Creating Appliance

* `vagrant up`
* `rm .vagrant/ip_cache.yml`
* `vagrant provision --provision-with hostmanager`
* `vagrant ssh -c "cat /etc/hosts" node[1-3]`
* `./ms-setup.pl`
* `./neuter-internet-repos.pl`
* Log into nodes and verify replication is working
* Run 'Purge the Things' below
* `$ opts="--vendor Percona --vendorurl https://www.percona.com/ --producturl https://github.com/percona/xtradb-cluster-tutorial"`
* `$ vagrant suspend`
* `$ VBoxManage export node1 node2 node3 -o ~/Downloads/20170807T1137-pxc-tutorial.ova --options manifest --vsys 0 $opts --vsys 1 $opts --vsys 2 $opts`

## Purge the Things

(as root)

    # Clear yum caches
    yum clean all

    # Cleanup log files
    find /var/log -type f | while read f; do echo -ne '' > $f; done

    # Clean out temp
    rm -rf /tmp/*

    # Whiteout root
    count=`df --sync -kP / | tail -n1  | awk -F ' ' '{print $4}'`
    let count--
    dd if=/dev/zero of=/tmp/whitespace bs=1024 count=$count
    rm /tmp/whitespace

    # Remove bash history
    unset HISTFILE
    rm -f /root/.bash_history
    rm -f /home/vagrant/.bash_history

    # Whiteout /boot
    count=`df --sync -kP /boot | tail -n1 | awk -F ' ' '{print $4}'`
    let count--
    dd if=/dev/zero of=/boot/whitespace bs=1024 count=$count
    rm /boot/whitespace

    # Zero out swap
    swapuuid=$(/sbin/blkid -o value -l -s UUID -t TYPE=swap)
    swappart=$(readlink -f /dev/disk/by-uuid/$swapuuid)
    swapoff $swappart
    dd if=/dev/zero of=$swappart bs=1M
    mkswap -U "${swapuuid}" "${swappart}"

    # Remove bash history
    unset HISTFILE
    rm -f /root/.bash_history
    rm -f /home/vagrant/.bash_history

    # Zero out remaining space
    dd if=/dev/zero of=/EMPTY bs=1M
    rm -f /EMPTY

    # Block until the empty file has been removed
    sync
