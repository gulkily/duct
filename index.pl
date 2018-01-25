#!/usr/bin/perl

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

# htmlroot under $SCRIPTDIR
my $HTMLDIR = "$SCRIPTDIR/html";

# htmlroot should exist
if (!-e $HTMLDIR || !-d $HTMLDIR) {
	die("Sanity check failed, $HTMLDIR doesn't exist\n");
}

# Get the top menu
sub GetMenu {
	my $MYNAME = shift;

	my $topMenu = GetTemplate('menu.nfo');
	$topMenu =~ s/$MYNAME/#/;
	return $topMenu;
}

sub GetIndex {
	my $txtIndex = "";

	# this will hold the title of the page
	my $title;

	# Look for the title in title.nfo, otherwise Untitled
	$title = trim(GetFile("title.nfo", 1024) || "Untitled");
	my $primaryColor = "#008080";

	# Get the htmlstart template
	my $htmlStart = GetTemplate('htmlstart.html.nfo');
	# and substitute $title with the title
	$htmlStart =~ s/\$title/$title/;
	$htmlStart =~ s/\$primaryColor/$primaryColor/g;

	# Print it
	$txtIndex .= $htmlStart;

	# If $title is set, print it as a header
	if ($title) {
		$txtIndex .= "<h1>$title</h1>";
	}

	my $pwd = `pwd`;
	my $MYNAME = trim(substr($pwd, length($HTMLDIR))) . "/";

	$txtIndex .= GetMenu($MYNAME);

	# Now the header, which should (todo) be different from the topmenu
	$txtIndex .= GetTemplate("header.nfo");

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
		$txtIndex .= "<ul>\n";
		foreach my $link(@foo) {
			my $url = substr($link, 0, index($link, " "));
			my $title = substr($link, index($link, " "));

			$txtIndex .= "<li><a href=\"$url\">$title</a></li>\n";

			$folderEmpty = 0;
		}
		$txtIndex .= "</ul>\n";
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
						$txtIndex .= '<h3><a href="' . $file . '">' . $fileTitle . '</a></h3>';

						$itemsPrinted++;
					}
				} else {
					my $txt = "";
					my $isSigned = 0;

					my $gpg_key;
					my $alias;

					my $gitHash;
					
					my $isAdmin = 0;

					if (substr($file, length($file) -4, 4) eq ".txt") {
						my %gpgResults = GpgParse($LocalPrefix . $file);

						$txt = $gpgResults{'text'};
						$isSigned = $gpgResults{'isSigned'};
						$gpg_key = $gpgResults{'key'};
						$alias = $gpgResults{'alias'};
						$gitHash = $gpgResults{'gitHash'};

						$txt = encode_entities($txt, '<>&"');
						$txt =~ s/\n/<br>\n/g;
						
						
						if ($isSigned && $gpg_key == GetAdminKey()) {
							$isAdmin = 1;
						}

						my $signedCss = "";
						if ($isSigned) {
							if ($isAdmin) {
								$signedCss = "signed admin";
							} else {
								$signedCss = "signed";
							}

							#todo un-hack this
							my $currentDir = $pwd;
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
							$txtIndex .= "<p class=\"txt $signedCss\">";

							if (substr($file, length($file) -4, 4) eq ".txt") {
								$txtIndex .= '<a class="header" href="' . $file . '.html">' . substr($file, 0, length($file) -4) . '</a>';
								$txtIndex .= ' <a class="header" href="' . $file . '">.txt</a>';
								
								if (-e "$file.comments" && -d "$file.comments") {
									$txtIndex .= ' <a class=header href="' . $file . '.comments/">comments</a>';
								} else {
									mkdir ("\"$file.comments\"");
									PutFile ("$file.comments/board.nfo", 1);
								}
								
								#$txtIndex .= ' (' . $gitHash . ')';
							} else {
								$txtIndex .= '<a class="header" href="' . $file . '">' . $file . '</a>';
							}
							$txtIndex .= '<br>' . $txt if $txt;
							
							if ($isSigned && $gpg_key) {
								#my $authorColor = substr($gpg_key, 0, 6);
								#my $authorAvatar = '<span style="background-color: #' . $authorColor . ';">*</span>';
								my $authorAvatar;
								$authorAvatar = GetAvatar($gpg_key);

								$txtIndex .= "<br><em class=\"$signedCss\">Signed, $authorAvatar <a href=\"/author/$gpg_key\">$alias</a></em>";
							}

							$txtIndex .= '</p>';

							###############
							## Generate HTML version of text file

							my $txtHtml = GetTemplate('htmlstart.html.nfo');
							$txtHtml =~ s/\$title/$file/;
							$txtHtml =~ s/\$primaryColor/$primaryColor/g;
							$txtHtml .= "<h1>" . $file . "</h1>";
							$txtHtml .= GetMenu($MYNAME);
							$txtHtml .= "<p class=\"txt $signedCss\">";

							if (substr($file, length($file) -4, 4) eq ".txt") {
								$txtHtml .= '<a class="header" href="' . $file . '.html">' . substr($file, 0, length($file) -4) . '</a>';
								$txtHtml .= ' <a class="header" href="' . $file . '">.txt</a>';
								#$txtHtml .= ' (' . $gitHash . ')';
							} else {
								$txtHtml .= '<a class="header" href="' . $file . '">' . $file . '</a>';
							}
							$txtHtml .= '<br>' . $txt if $txt;

							$txtHtml .= "<br><em class=signed>Signed, <a href=\"/author/$gpg_key\">$alias</a></em>" if ($isSigned && $gpg_key);
							$txtHtml .= "</p>";
							$txtHtml .= GetMenu($MYNAME);
							$txtHtml .= GetTemplate("htmlend.nfo");

							PutFile($LocalPrefix . $file . ".html", $txtHtml);

							##
							###############

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
		$txtIndex .= GetTemplate("forma.html.nfo");

		# Make sure the submission form has somewhere to go
		PutFile("gracias.html", GetTemplate('gracias.html.nfo'));
	}

	my $makeZip = GetFile("makezip.nfo");
	my $zipName;

	# If we want a zip file (makezip.nfo == 1)
	if ($makeZip) {
		$zipName = substr($pwd, rindex($pwd, '/') + 1);
		chomp($zipName);

		my $makeZipFile = `zip -vr "$zipName.zip" .`; #debug comment

		PutFile("$zipName.zip.nfo", "#");
		PutFile("$zipName.zip.log", $makeZipFile);
	}

	# If there is a horoscope.lst file, write a random line from it
	my $horoscopeFile = "horoscope.lst";
	if (open FILE, "<$horoscopeFile") {
		srand;
		my @array = <FILE>;
		close FILE;

		my $randomline = $array[rand @array];
		$txtIndex .= "<p>";
		$txtIndex .= $randomline;
		$txtIndex .= "</p>";

		$folderEmpty = 0;
		$itemsPrinted++;
	}

	# If nothing was printed, say the folder is empty
	if ($folderEmpty) {
		$txtIndex .= "<p>(This folder appears to be empty.)</p>";
	}

	# Save the number of items
	PutFile("itemCount.nfo", $itemsPrinted);

	# Read the counters
	my $counter = trim(GetFile("counter.nfo"));

	# If either of the counters exists, output it
	if ($counter) {
		$txtIndex .= "<p>";
		$txtIndex .= "This page has been requested <span class=counter>" . $counter . "</span> times.";
		$txtIndex .= "</p>";
	}

	if ($makeZip) {
		$txtIndex .= "<p>";
		$txtIndex .= "Download a zip file of this directory: <a href=\"$zipName.zip\">$zipName.zip</a>";
		$txtIndex .= "</p>";
	}

	# Print the same menu as at the top of the page
	$txtIndex .= GetMenu($MYNAME);

	# Close html
	$txtIndex .= GetTemplate("htmlend.nfo");

	return $txtIndex;
}

my $htmlIndex = GetIndex(".");

print $htmlIndex;

1;
