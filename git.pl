#!/usr/bin/perl

use strict;
use utf8;

my @files = `git diff --name-only -r`;



foreach my $file (@files) {
	chomp($file);
	if ($file eq 'log/access.log') {
		print "access.log seems to have changed, running access.pl\n";
		my @accessLogResults = `perl ./access.pl`;
		print `git add log/access.log`;
	} else {
		print "not sure what to do with $file\n";
	}
}

