#!/usr/bin/perl

use strict;
use utf8;

my @dirsToIndex;

sub indexTxtFile {
	# clean this up later #todo
	# commented lines need variables left behind in index.pl
	my $file = shift;
	chomp $file;

	my %gpgResults = GpgParse($file);
}

sub getDir {
	# gets directory from filename
	my $file = shift;
	chomp $file;

	my $dir = substr($file, 0, rindex($file, '/'));

	return $dir;
}

sub isTxt {
	# is it a .txt file?
	my $file = shift;
	chomp $file;

	if (substr($file, length($file) -4, 4) eq ".txt") {
		return 1;
	} else {
		return 0;
	}
}

sub isLst {
	# is it a .lst file?
	my $file = shift;
	chomp $file;

	if (substr($file, length($file) -4, 4) eq ".lst") {
		return 1;
	} else {
		return 0;
	}
}

# Write the index for directory
# $dir = directory to index, no trailing slash
sub indexDir {
	my $dir = shift;

	my $SCRIPTDIR = "/home/pi/duct"; #todo hardcoded

	# use $SCRIPTDIR global to determine path of helper scripts
	my $pathToIndexPl = "$SCRIPTDIR/index.pl $SCRIPTDIR";

	print "Writing index for directory $dir\n";

	print "mkdir -p $dir; cd $dir; perl $pathToIndexPl > index.html.tmp; mv index.html.tmp index.html\n";

	system("mkdir -p $dir; cd $dir; perl $pathToIndexPl > index.html.tmp; mv index.html.tmp index.html");

	# If it's a board, call sorter.pl on it
	if (GetFile("$dir/sorter.nfo")) {
		sortDir($dir);
	}
}

sub indexFile {
	my $file= shift;
	chomp $file;

	print "indexFile $file\n";

	if (isTxt($file)) {
		print `git add "$file"`;
		indexTxtFile($file);
		print `git commit -m txt "$file"`;

		return 1;
	}
	elsif (isLst($file)) {
		print `git add "$file"`;
		push @dirsToIndex, getDir($file);
		print `git commit -m lst "$file"`;
	}
}

# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`;
chomp $SCRIPTDIR;

print "Using $SCRIPTDIR as install root...\n";

# We'll use ./html as the web root
#my $HTMLDIR = "$SCRIPTDIR/html/";
my $HTMLDIR = "html/";

if (!-e './utils.pl') {
	die ("Sanity check failed, can't find utils.pl");
}
require './utils.pl';

##########################################################

my @files = `git diff HEAD --name-only -r`;

foreach my $file (@files) {
	chomp($file);
	if ($file eq 'log/access.log') {
		print "access.log seems to have changed, running access.pl\n";
		my @accessLogResults = `perl ./access.pl`;
		print `git add log/access.log`;
	} elsif (substr($file, 0, length($HTMLDIR)) eq $HTMLDIR) {
		if (indexFile($file)) {
			push @dirsToIndex, getDir($file);
		}
	} else {
		print "not sure what to do with $file\n";
	}
}

foreach my $dir (@dirsToIndex) {
	indexDir($dir);
}
