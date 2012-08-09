#!/usr/bin/perl

# reduce the nodes to a baseline install

my @nodes = qw/ node1 node2 node3 /;

foreach my $node( @nodes ) {
	print "Baselining $node\n";
	system( "vagrant ssh $node -c \"sudo /usr/local/bin/baseline.sh\"" );
}