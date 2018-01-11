#!/usr/bin/perl

use strict;
use utf8;

# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`;
chomp $SCRIPTDIR;

print "Using $SCRIPTDIR as install root...\n";

# We'll use ./html as the web root
my $HTMLDIR = "$SCRIPTDIR/html/";

print "Verifying that $HTMLDIR exists...\n";
if (!-e $HTMLDIR || !-d $HTMLDIR) {
	if (-e "$SCRIPTDIR/default_html") {
		print "$HTMLDIR is missing, creating it and populating from default_html";
		system("cd $SCRIPTDIR; mkdir html; cp -r default_html/* html");
	}
	die ("Sanity check failed, \$HTMLDIR=$HTMLDIR, but it isn't a directory");
}

if (!-e './utils.pl') {
	die ("Sanity check failed, can't find utils.pl");
}
require('./utils.pl');

if (!-e 'sorter.pl') {
	die("Sanity check failed, can't find sorter.pl");
}
require('./sorter.pl');

# This is where the generated HTML lives
my $HTMLDIR = $SCRIPTDIR . "/html";

# Directories we'll start with
my @dirsToIndex = (
	"$HTMLDIR",
	"$HTMLDIR/author",
	"$HTMLDIR/text",
	"$HTMLDIR/test",
);

# Write the index for directory
# $dir = directory to index, no trailing slash
sub indexDir {
	my $dir = shift;

	# use $SCRIPTDIR global to determine path of helper scripts
	my $pathToIndexPl = "$SCRIPTDIR/index.pl $SCRIPTDIR";
	#my $pathToSorterPl = "$SCRIPTDIR/sorter.pl";

	print "Writing index for directory $dir\n";

	print "mkdir -p $dir; cd $dir; perl $pathToIndexPl > index.html.tmp; mv index.html.tmp index.html\n";

	system("mkdir -p $dir; cd $dir; perl $pathToIndexPl > index.html.tmp; mv index.html.tmp index.html");

	# If it's a board, call sorter.pl on it
	if (GetFile("$dir/sorter.nfo")) {
		#print "cd $SCRIPTDIR; perl $pathToSorterPl $dir";

		#system("cd $SCRIPTDIR; perl $pathToSorterPl $dir");

		sortDir($dir);
	}
}

# Index sub-directories of a directory
sub indexSubDirs {
	my $dir = shift;

	print "indexSubDirs($dir)\n";

	my @files = glob("$dir/*");

	foreach my $file (@files) {
		if (-d $file) {
			print "calling indexDir($file)\n";
			indexDir ("$file");
		}
	}
}


################

# Write the newest items index
my @newestFiles = `cd $HTMLDIR; find . -type f -printf '%T@ %p\n' | sort -n | cut -f2- -d" "`;

# Counts files printed into list
my $filesPrinterCounter;

# Where we store the new, de-duped index
my $newFilesIndex;

foreach my $file (@newestFiles) {
	if (
		!($file eq 'index.html') &&
		!($file eq 'gracias.html') &&
		!(substr($file, length($file) - 4, 4) eq ".nfo") &&
		!(substr($file, length($file) - 4, 4) eq ".lst")
	) {
		$filesPrinterCounter++;

		if ($filesPrinterCounter > 20) {
			last;
		}

		chomp $file;

		$file = substr($file, 1);

		$newFilesIndex .= "$file\n";

	}

	PutFile("$HTMLDIR/newest/index.lst", $newFilesIndex);
}

###############################

# Index everything in @dirsToIndex
foreach my $dir (@dirsToIndex) {
	indexDir ($dir);

	indexSubDirs($dir);
}

# Trims the directories and the file extension from a file path
sub TrimPath {
	my $string = shift;

	while (index($string, "/") >= 0) {
		$string = substr($string, index($string, "/") + 1);
	}

	$string = substr($string, 0, index($string, "."));

	return $string;

}

# Create an index for all the authors
my @authorIndexes = glob("$HTMLDIR/author/*.lst");

foreach my $authorIndex (@authorIndexes) {
	# Extract the author's name
	my $author = TrimPath($authorIndex);

	print "Creating author index page for $author\n";

	# Make sure directory for author exists
	print "Checking for $HTMLDIR/author/$author\n";
	if (!-d "$HTMLDIR/author/$author") {
		print "Creating $HTMLDIR/author/$author\n";
		system(`mkdir -p $HTMLDIR/author/$author`);
	}

	# Get the author's posts from the index
	open my $handle, '<', $authorIndex;
	chomp(my @postsByAuthor = <$handle>);
	close $handle;

	# Filter for dupes and remove files that don't exist
	my %unique = ();
	foreach my $item (@postsByAuthor) {
		if (-e "$HTMLDIR$item") {
			$unique{$item} ++;
		}
	}
	@postsByAuthor = keys %unique;

	# Save the list while also generating an index
	open my $handle, '>', $authorIndex;

	foreach my $post (@postsByAuthor) {
		print $handle "$post\n";

	}
	close $handle;

	my $alias = GetFile("$HTMLDIR/author/$author/alias.nfo");
	if ($alias) {
		$alias = encode_entities($alias, '<>&"');
		PutFile("$HTMLDIR/author/$author.nfo", "Posts by $alias");
		PutFile("$HTMLDIR/author/$author/title.nfo", "Posts by $alias");
	} else {
		PutFile("$HTMLDIR/author/$author.nfo", "Posts by $author");
		PutFile("$HTMLDIR/author/$author/title.nfo", "Posts by $author");
	}
	PutFile("$HTMLDIR/author/$author/index.lst", join("\n", @postsByAuthor));

	#indexDir("$HTMLDIR/author/$author");
}

1;
