#!/usr/bin/perl


print "Disable internet repos from running nodes\n";

# setup all nodes in replication with the first node in `vagrant status` as the master.

my @running_nodes_lines = `vagrant status | grep running`;
my @running_nodes;
foreach my $line( @running_nodes_lines ) {
	if( $line =~ m/^(\w+)\s+\w+\s+\((\w+)\)$/ ) {
		push( @running_nodes, {
			name => $1,
			provider => $2
		});
	}
}

# Harvest node ips
foreach my $node( @running_nodes ) {
	print $node->{name} . " disabling\n";

	`vagrant ssh $node->{name} -c "sudo mkdir /etc/yum.repos.internet; \
sudo mv /etc/yum.repos.d/* /etc/yum.repos.internet; \
sudo cp /etc/yum.repos.internet/local.repo /etc/yum.repos.d"`;
}
