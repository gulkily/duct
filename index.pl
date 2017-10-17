#!/usr/bin/perl

# todo this file should write to a specified file
# as opposed to outputting to stdout

use strict;
use utf8;

# This is the install dir, which should be passed in as the first argument
my $SCRIPTDIR=shift;

# $SCRIPTDIR should exist
if (!-e $SCRIPTDIR || !-d $SCRIPTDIR) {
	die ("Sanity check failed, $SCRIPTDIR doesn't exist\n");
}

# utils
require "$SCRIPTDIR/utils.pl";

# we need this
use HTML::Entities;
use Date::Parse;

# currently doesn't do anything
my $DEBUG=1;

# this will hold the title of the page
my $title;

# htmlroot under $SCRIPTDIR
my $HTMLDIR = "$SCRIPTDIR/html";

# htmlroot should exist
if (!-e $HTMLDIR || !-d $HTMLDIR) {
	die("Sanity check failed, $HTMLDIR doesn't exist\n");
}

# Gets template from current dir or template dir
# Should not fail
sub GetTemplate {
	my $filename = shift;
	my $length = 10240;

	if (-e $filename) {
		return GetFile($filename);
	} else {
		return GetFile("$SCRIPTDIR/template/$filename");
	}

	die("GetTemplate failed, something is probably wrong");
}

# Look for the title in title.nfo, otherwise Untitled
$title = trim(GetFile("title.nfo", 1024) || "Untitled");
my $primaryColor = "#008080";

# Get the htmlstart template
my $htmlStart = GetTemplate('htmlstart.html.nfo');
# and substitute $title with the title
$htmlStart =~ s/\$title/$title/;
$htmlStart =~ s/\$primaryColor/$primaryColor/g;

# Print it
print $htmlStart;

# If $title is set, print it as a header
if ($title) {
	print "<h1>$title</h1>";
}

my $pwd = `pwd`;
my $MYNAME = trim(substr($pwd, length($HTMLDIR))) . "/";

# Print the top menu
sub PrintMenu {
	my $topMenu = GetTemplate('menu.nfo');
	$topMenu =~ s/$MYNAME/#/;
	print $topMenu;
}

PrintMenu();

# Now the header, which should (todo) be different from the topmenu
print GetTemplate("header.nfo");

# @foo will hold the list of files or links
my @foo;

# $LocalPrefix is used for storing the local html path
my $LocalPrefix = "";

# $httpLinks is a flag set to 1 when printing items from links.lst
# instead of a file list
my $httpLinks = 0;

# $itemsPrinted is a counter of items printed.
# If it is 0 after everything, we will print a message that
# the folder is empty
my $itemsPrinted = 0;
my $folderEmpty = 1;

# If there is an index.lst, use that
if (GetFile('index.lst')) { #todo don't read same file twice
	@foo = split("\n", GetFile('index.lst'));
	$LocalPrefix = $HTMLDIR;
	# $LocalPrefix is for when we read the file locally to include it as
	# part of the file listing
# If there is a links.lst file, use that
} elsif (GetFile('links.lst')) { #todo don't read the same file twice
	@foo = split("\n", GetFile('links.lst'));
	$httpLinks = 1;
	# Treat these lines as HTTP links
# If there is a "listsubs.nfo" file, include subdirectories in the listing
} elsif (GetFile("listsubs.nfo")) {
	@foo = `find .`;
# Otherwise just use ls -t, which lists the current directory, sorted by timestamp
} else {
	@foo = `ls -t`;
}

# Http links get their own, much simpler output loop
if ($httpLinks) {
	print "<ul>\n";
	foreach my $link(@foo) {
		my $url = substr($link, 0, index($link, " "));
		my $title = substr($link, index($link, " "));

		print "<li><a href=\"$url\">$title</a></li>\n";
	}
	print "</ul>\n";
# This lists the local files
# Todo break some of this out into subs
# Todo this currently includes uncached gpg verification
} else {
	# $BoardMode enables inline printing the contents of .txt files
	# board.nfo should contain "1" to enable it
	# todo disabled for now, needs to be decoupled from comment form
	my $BoardMode = GetFile("board.nfo");

	foreach my $file (@foo) {
		chomp($file);

		if (
			!($file eq 'index.html') &&
			!($file eq 'index.pl') &&
			!($file eq 'index.html.tmp') &&
			!($file eq 'gracias.html') &&
			!(substr($file, length($file) - 4, 4) eq ".nfo") &&
			!(substr($file, length($file) - 4, 4) eq ".lst")
		) {
			my $filenfo = GetFile($LocalPrefix . $file . ".nfo");
			chomp ($filenfo);
			my $fileTitle = ( split /\n/, $filenfo )[0];

			if ($fileTitle && -d $file && !-e "$file/title.nfo") {
				# If there's a $dir.nfo but no $dir/title.nfo, write
				# a title.nfo
				PutFile("$file/title.nfo", $fileTitle);
			}

			if (-d $file && -e "$file/title.nfo" && !$fileTitle) {
				# And the opposite, if there's title.nfo inside a directory, but
				# no directory.nfo, copy the title from $dir/title.nfo
				PutFile($LocalPrefix . $file . ".nfo", GetFile("$file/title.nfo"));
			}

			$folderEmpty = 0;

			if ($fileTitle) {
				if (!($fileTitle eq '#')) {
					if (-d $file && -e "$file/itemCount.nfo" && GetFile("$file/itemCount.nfo")) {
						$fileTitle .= " (" . GetFile("$file/itemCount.nfo") . ")";
					}
					print '<h3><a href="' . $file . '">' . $fileTitle . '</a></h3>';

					$itemsPrinted++;
				}
			} else {
				my $txt = "";
				my $isSigned = 0;

				my $gpg_key;
				my $alias;

				if (substr($file, length($file) -4, 4) eq ".txt") {
					my %gpgResults = GpgParse($LocalPrefix . $file);
					#print %gpgResults;

					$txt = $gpgResults{'text'};
					$isSigned = $gpgResults{'isSigned'};
					$gpg_key = $gpgResults{'key'};
					$alias = $gpgResults{'alias'};

					$txt = encode_entities($txt, '<>&"');
					$txt =~ s/\n/<br>\n/g;


					my $signedCss = "";
					if ($isSigned) {
						$signedCss = "signed";

						#todo un-hack this
						my $currentDir = `pwd`;
						chomp ($currentDir);
						my $currentDir = substr($currentDir, length($HTMLDIR));

						AppendFile("$HTMLDIR/author/$gpg_key.lst", $currentDir . "/" . $file);

						if ($alias) {
							PutFile("$HTMLDIR/author/$gpg_key/alias.nfo", $alias);
						}
					}

					if (!$alias) {
						if (-e "$HTMLDIR/author/$gpg_key/alias.nfo") {
							$alias = GetFile("$HTMLDIR/author/$gpg_key/alias.nfo");
							chomp($alias);
						} else {
							$alias = $gpg_key;
						}
					}


					$alias = encode_entities($alias, '<>&"');
					$alias =~ s/\n/<br>\n/g;


					#if ($BoardMode) {
						print "<p class=\"txt $signedCss\">";

						if (substr($file, length($file) -4, 4) eq ".txt") {
							print '<a class="header" href="' . $file . '.html">' . substr($file, 0, length($file) -4) . '</a>';
							print ' <a class="header" href="' . $file . '">.txt</a>';
						} else {
							print '<a class="header" href="' . $file . '">' . $file . '</a>';
						}
						print '<br>' . $txt if $txt;

						print "<br><em class=signed>Signed, <a href=\"/author/$gpg_key\">$alias</a></em>" if ($isSigned && $gpg_key);

						print '</p>';

						my $txtHtml = GetTemplate('htmlstart.html.nfo');
						$txtHtml =~ s/\$title/$file/;
						$txtHtml =~ s/\$primaryColor/$primaryColor/g;
						$txtHtml .= "<h1>" . $file . "</h1>";
						$txtHtml .= "<p class=\"txt $signedCss\">";
						$txtHtml .= "$txt";
						$txtHtml .= "<br><em class=signed>Signed, <a href=\"/author/$gpg_key\">$alias</a></em>" if ($isSigned && $gpg_key);
						$txtHtml .= "</p>";
						$txtHtml .= GetTemplate('menu.nfo');
						$txtHtml .= GetTemplate("htmlend.nfo");

						PutFile($LocalPrefix . $file . ".html", $txtHtml);

						$itemsPrinted++;
					#}
				}
			}
		}
	}
}

# If it's a board (board.nfo == 1)
if (GetFile("board.nfo")) {
	# Add a submission form to the end of the page
	print GetTemplate("forma.html.nfo");

	# Make sure the submission form has somewhere to go
	PutFile("gracias.html", GetTemplate('gracias.html.nfo'));
}

# If there is a horoscope.lst file, write a random line from it
my $horoscopeFile = "horoscope.lst";
if (open FILE, "<$horoscopeFile") {
	srand;
	my @array = <FILE>;
	close FILE;

	my $randomline = $array[rand @array];
	print "<p>";
	print $randomline;
	print "</p>";

	$folderEmpty = 0;
	$itemsPrinted++;
}

# If nothing was printed, say the folder is empty
if ($folderEmpty) {
	print "<p>(This folder appears to be empty.)</p>";
}

# Save the number of items
PutFile("itemCount.nfo", $itemsPrinted);

# Read the counters
my $counter = trim(GetFile("counter.nfo"));
my $genCount = trim(GetFile("gencount.nfo")) + 1;

# If either of the counters exists, output it
if ($counter || $genCount) { print "<p>" };
if ($counter) {
	print "This page has been requested <span class=counter>" . $counter . "</span> times.";
}
if ($genCount) {
	PutFile("gencount.nfo", $genCount);
	if ($counter) { print " "; }
	print "This page has been generated <span class=counter>" . $genCount . "</span> times.";
}
if ($counter || $genCount) { print "</p>" };

# Print the same menu as at the top of the page
PrintMenu();

# Close html
print GetTemplate("htmlend.nfo");
