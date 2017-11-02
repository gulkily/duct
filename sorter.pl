#!/usr/bin/perl

use strict;
use utf8;

## CONFIG AND SANITY CHECKS ##

# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`;
chomp $SCRIPTDIR;

print "Using $SCRIPTDIR as install root...\n";

# We'll use ./html as the web root
my $HTMLDIR = "$SCRIPTDIR/html/";

print "Verifying that $HTMLDIR exists...\n";
if (!-e $HTMLDIR || !-d $HTMLDIR) {
	die ("Sanity check failed, \$HTMLDIR=$HTMLDIR, but it isn't a directory");
}

if (!-e 'utils.pl') {
	die ("Sanity check failed, can't find utils.pl");
}
require 'utils.pl';

#####################

sub sortDir {
	my $filenameDir = shift;
	chomp($filenameDir);

	print "Looking for $filenameDir/*_*.txt\n";

	# search through all the txt files
	my @files = glob("$filenameDir/*_*.txt");

	# format current date in proper format DDMmmYYYY
	my $currentDate = trim(`date +%d%b%Y`);
	my $currentMonth = trim(`date +%b%Y`);

	foreach my $file (@files) {
		print "$file\n";

		my $fileName;
		$fileName = substr($file, length($filenameDir) + 1);

		# Ignore files without an underscore in the name or that begin with an underscore
		if (index($fileName, "_") > 2) {
			# The date is the thing before the underscore
			my $fileDate = substr($fileName, 0, index($fileName, "_"));
			my $fileMonth = substr($fileDate, 2);

			# If it is not the current date...
			if ($fileMonth ne $currentMonth) {
				# ... make sure that directory exists...
				my $dirName = "$filenameDir/$fileMonth";
				if (!-d $dirName && !-e $dirName) {
					print "Creating $dirName\n";
					mkdir ($dirName);
				}

				# ... and then move the file into it
				if (-d $dirName) {
					print "Moving $file to $dirName\n";
					rename($file, $dirName . "/" . substr($file, rindex($file, "/")));
				}
			}
		}
	}
}

#my $dirToSort = shift;
#chomp ($dirToSort);

#if (-e $dirToSort && -d $dirToSort) {
#	print "$dirToSort exists, proceeding...\n";
#} else {
#	die "Sanity check failed, $dirToSort doesn't exist";
#}

#if (-e "$dirToSort/board.nfo" && GetFile("$dirToSort/board.nfo") == 1) {
#	print "$dirToSort/board.nfo contains expected 1, proceeding...\n";
#} else {
#	die("Couldn't find needed $dirToSort/board.nfo");
#}

#sortDir("$SCRIPTDIR/html/test");

1;
