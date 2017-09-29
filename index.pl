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
#use Date::Parse;

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

# Get the htmlstart template
my $htmlStart = GetTemplate('htmlstart.html.nfo');
# and substitute $title with the title
$htmlStart =~ s/\$title/$title/;

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
	my $BoardMode = 1; #GetFile("board.nfo");
		
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
				#print "Writing a title.nfo for $file, since it doesn't exist";
				PutFile("$file/title.nfo", $fileTitle);
			}
			
			$itemsPrinted++;

			if ($fileTitle) {
				if (!($filenfo eq '#')) {
					print '<h3><a href="' . $file . '">' . $filenfo . '</a></h3>';
				}
			} else {
				
				
				my $txt = "";
				my $isSigned = 0;
				
				my $gpg_key;

				if (substr($file, length($file) -4, 4) eq ".txt") {
					$txt = trim(GetFile($LocalPrefix . $file));
													
					# This is where we check for a GPG signed message and sort it accordingly
					my $gpg_header = "-----BEGIN PGP SIGNED MESSAGE-----";

					# If there is a GPG header...
					if (substr($txt, 0, length($gpg_header)) eq $gpg_header) {
						# Verify the file by using command-line gpg
						# --status-fd 1 makes gpg output to STDOUT using a more concise syntax
						my $gpg_result = `gpg --verify --status-fd 1 "$LocalPrefix$file"`;
						
						my $key_id_prefix;
						my $key_id_suffix;

						if (index($gpg_result, "[GNUPG:] NO_PUBKEY ") >= 0) {
							$key_id_prefix = "[GNUPG:] NO_PUBKEY ";
							$key_id_suffix = "\n";
						}
						
						if (index($gpg_result, "[GNUPG:] GOODSIG ") >= 0 ) {
							$key_id_prefix = "[GNUPG:] GOODSIG ";
							$key_id_suffix = " ";
						}
											
						if ($key_id_prefix) {						
							# Extract the key fingerprint from GPG's output.
							$gpg_key = substr($gpg_result, index($gpg_result, $key_id_prefix) + length($key_id_prefix));
							$gpg_key = substr($gpg_key, 0, index($gpg_key, $key_id_suffix));

							$txt = `gpg --decrypt "$LocalPrefix$file"`;
															
							$gpg_key = encode_entities($gpg_key);
							$gpg_key =~ s/\n/<br>\n/g;
							
							$isSigned = 1;
							
							my $fullPath;
							if (index($file, '/') < 0) {
								$fullPath = substr(trim(`pwd`) . "/" . $file, length($HTMLDIR));
							} else {
								$fullPath = $file;
							} #todo this is kind of a hack
							AppendFile("$HTMLDIR/author/$gpg_key.lst", $fullPath);
						}
					}
										
					$txt = encode_entities($txt, '<>&"');
					$txt =~ s/\n/<br>\n/g;
				}
				
				my $signedCss = "";
				if ($isSigned) {
					$signedCss = "signed";
				}
				
				#if ($BoardMode) {
					print "<p class=\"txt $signedCss\">";
					print '<a class="header" href="' . $file . '">' . $file . '</a>';
					print '<br>' . $txt if $txt;
					
					print "<br><em class=signed>Signed, <a href=\"/author/$gpg_key\">$gpg_key</a></em>" if ($isSigned && $gpg_key);
					
					print '</p>';
				#}
				

				#my $txtHtml = GetTemplate('htmlstart.html.nfo');
				#$txtHtml =~ s/\$title/$file/;
				#$txtHtml .= GetTemplate('header.nfo');
				#$txtHtml .= "<p>$txt</p>";
				#$txtHtml .= GetTemplate('footer.nfo');
				#$txtHtml .= GetTemplate("htmlend.nfo");
				
				#PutFile($LocalPrefix . $file . ".html", $txtHtml);
			}
		}
	}
}

if (GetFile("board.nfo")) {
	print GetTemplate("forma.html.nfo");
	
	PutFile("gracias.html", GetTemplate('gracias.html.nfo'));
}

my $horoscopeFile = "horoscope.lst";
if (open FILE, "<$horoscopeFile") {
	srand;
	my @array = <FILE>;
	close FILE;
	
	my $randomline = $array[rand @array];
	print "<p>";
	print $randomline;
	print "</p>";
	
	$itemsPrinted++;
}

if (!$itemsPrinted) {
	print "<p>(This folder appears to be empty.)</p>";
}

my $counter = trim(GetFile("counter.nfo"));
my $genCount = trim(GetFile("gencount.nfo")) + 1;

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


PrintMenu();

print GetTemplate("htmlend.nfo");
