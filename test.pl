#!/usr/bin/perl

use strict;
use utf8;

my @files = `find . | grep "\.txt\$"`;

foreach (@files) {
	chomp;
	print `sha256sum "$_"`, "\n";

}
