#!/usr/bin/perl -w

use strict;

my $threshold = 0.050; #50ms

use Time::HiRes qw/ gettimeofday tv_interval sleep /;
use DBI;

$| = 1;

my $dbh = DBI->connect( "DBI:mysql:database=percona", 'root', '' ) or die "Could not connect: $!";
my $i = 0;

while( 1 ) {
	my $start = [gettimeofday];
	
	$dbh->do("update heartbeat set ts=NOW() where id=1" ) or die "Could not update!: $!";
	
	my $interval = tv_interval( $start );
	if( $interval > $threshold ) {
		my $date = `date`; chop $date;
		print "\nslow: $date ";	
		printf( "%.3fs\n", $interval );
	} else {
		print "\r" . $i++;
		sleep( 0.010 );
	}
}