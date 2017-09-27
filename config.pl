#!/usr/bin/perl

use strict;
use utf8;

sub GetConfig {
	my $key; 
	
	shift $key;
	
	my %config = (
		"SCRIPTDIR" = "/home/pi/wisebody"
	);
	
	if (exists($config{$key})) {
		return $config{$key};
	} else {
		return null;
	}

}

1;
