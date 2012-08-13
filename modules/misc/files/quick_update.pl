#!/usr/bin/perl -w

use strict;

use AnyEvent;
use AnyEvent::DBI;

use Time::HiRes qw/ gettimeofday tv_interval sleep /;

$| = 1;

my $threshold = 0.050; #50ms

my( $last_complete, $flag );

my $count = 0;
sub finished_query {
	if( $flag ) {
		printf( "%.3fs\n", tv_interval( $last_complete ));
		
	}
		
	$flag = 0;
	$count++;
	
	print "\r$count";
}

my $cv = AnyEvent->condvar;

my $dbh = new AnyEvent::DBI "DBI:mysql:dbname=percona", 'root', '';

&finished_query();



sub query_done {
	my ($dbh, $rows, $rv) = @_;
	
	&finished_query();
	sleep( 0.010 );
	
	&run_query();
}

sub run_query {
	$last_complete = [gettimeofday];
	$dbh->exec ("update heartbeat set ts=NOW() where id=1", *query_done );	
}

&run_query();

my $idle = AnyEvent->idle(cb => sub {
	unless( $flag ) {
		my $interval = tv_interval( $last_complete );
		
		if( $interval > $threshold ) {
			print "\nslow\n";	
			system( "date" );
			$flag = 1;
		}
	}
});

$cv->wait;