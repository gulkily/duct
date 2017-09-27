#!/usr/bin/perl

use strict;
use utf8;

my @friends = (
	'bodywise.local',
	#'wisebodyasltpgf3.onion',
);

my @dirs = (
	'text',
	'nyc',
);

foreach my $friend (@friends) {
	my $torify = '';
	
	if (substr($friend, length($friend) - 6, 6) eq '.onion') {
		$torify = 'torify';
	}
	
	foreach my $dir (@dirs) {
		
		system ("mkdir -p $friend; cd $friend; $torify wget -r -l 1 http://$friend/$dir/");
	}
	#system('cd bodywise; wget -r -l 1 http://bodywise.local/');
	
}
