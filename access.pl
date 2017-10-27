#!/usr/bin/perl

# This file parses the access logs
# It posts messages to /text/
# It also updates the visit counters

use strict;
use utf8;

## CONFIG AND SANITY CHECKS ##

# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`;
chomp $SCRIPTDIR;

print "Using $SCRIPTDIR as install root...\n";

if (!-e 'utils.pl') {
	die ("Sanity check failed, can't find utils.pl in $SCRIPTDIR");
}
require 'utils.pl';

# We'll use ./html as the web root
my $HTMLDIR = "$SCRIPTDIR/html/";

print "Verifying that $HTMLDIR exists...\n";
if (!-e $HTMLDIR || !-d $HTMLDIR) {
	die ("Sanity check failed, \$HTMLDIR=$HTMLDIR, but it isn't a directory");
}

# Logfile for default site domain
# In Apache, use CustomLog, e.g.:
#         CustomLog /foo/bar/log/access.log combined

my $LOGFILE = "$SCRIPTDIR/log/access.log";
print "\$LOGFILE=$LOGFILE\n";


# Path to index-maker
my $INDEXER = "$SCRIPTDIR/index.pl";
if (!-e $INDEXER) {
	die ("Sanity check failed, can't find $INDEXER");
}

##################

# Prefixes we will look for in access log to find comments
# and their corresponding drop folders
# Wherever there is a gracias.html and board.nfo exists
# todo add check for board.nfo

my @submitReceivers = `find ./html/ | grep gracias.html`; #todo this is a hack

foreach (@submitReceivers) {
	s/^\.\/html//;
	s/$/\?comment=/;
	chomp;
}

##################


# ProcessAccessLog (
#	access log file path
#   parse mode:
#		0 = default site log
#		1 = vhost log
# )
sub ProcessAccessLog {
	my $logfile = shift;       # Path to log file
	my $vhostParse = shift;    # Whether we use the vhost log format

	print "Processing $logfile...\n";

	# The log file should always be there
	open(LOGFILE, $logfile) or die("Could not open log file.");

	# The following section parses the access log
	# Thank you, StackOverflow
	foreach my $line (<LOGFILE>) {
		#print ".";

		# These are the values we will pull out of access.log
		my $site;
		my $hostname;
		my $logName;
		my $fullName;
		my $date;
		my $gmt;
		my $req;
		my $file;
		my $proto;
		my $status;
		my $length;
		my $ref;

		# Parse mode select
		if ($vhostParse) {
			# Split the log line
			($site, $hostname, $logName, $fullName, $date, $gmt,
				 $req, $file, $proto, $status, $length, $ref) = split(' ',$line);
		} else {
			# Split the log line
			($hostname, $logName, $fullName, $date, $gmt,
				 $req, $file, $proto, $status, $length, $ref) = split(' ',$line);
		}

		# Split $date into $time and $date
		my $time = substr($date, 13);
		my $date = substr($date, 1, 11);

		# todo add comment here
		$req  = substr($req, 1);
		chop($gmt);
		chop($proto);

		# These are all the counters we are updating
		# The counter values are stored in .nfo files
		# Should be moved to the top of this file
		my %counters = (
			"/"  => "html/counter.nfo",
			"/text/" => "html/text/counter.nfo",
			"/docs/" => "html/docs/counter.nfo",
			"/temp/" => "html/temp/counter.nfo",
			"/library/" => "html/library/counter.nfo",
			"/horoscope/" => "html/horoscope/counter.nfo"
		);

		# If requested page has a counter...
		if ($counters{$file}) {
			my $counterFile;
			my $counter;

			# todo this whole thing should use GetFile and PutFile
			# also it should create the counter file if it doesn't exist?

			# Read the value
			if (open ($counterFile, "<", $counters{$file})) {
				read ($counterFile, $counter, 10240);
				close $counterFile;

				# Increment the counter
				$counter++;

				#Write the new value
				if (open ($counterFile, ">", $counters{$file})) {
					print $counterFile $counter;
					close $counterFile;
				}
			}
		}

		## TEXT SUBMISSION PROCESSING BEGINS HERE ##
		############################################

		# Now we see if the user is posting a message
		# We do this by looking for $submitPrefix,
		# which is something like /text/gracias.html?comment=...

		my $submitPrefix;
		my $submitTarget;

		# Look for submitted text wherever gracias.html exists
		foreach (@submitReceivers) {
			if (substr($file, 0, length($_)) eq $_) {
				$submitPrefix = $_;
				$submitTarget = substr($_, 1);
				$submitTarget = substr($submitTarget, 0, rindex($submitTarget, "gracias.html"));
				last;
			}
		}

		# If a submission prefix was found
		if ($submitPrefix) {
			# Look for it in the beginning of the requested URL
			if (substr($file, 0, length($submitPrefix)) eq $submitPrefix) {
				print "Found a message...\n";

				# The message comes after the prefix, so just trim it
				my $message = (substr($file, length($submitPrefix)));

				# Unpack from URL encoding, probably exploitable :(
				$message =~ s/\+/ /g;
				$message = uri_decode($message);
				$message = decode_entities($message);
				$message = trim($message);

				# If we're parsing a vhost log, add the site name to the message
				if ($vhostParse && $site) {
					$message .= "\n" . $site;
				}

				# Generate filename from date and time
				my $filename;

				$filename = $date . '_' . $time;
				$filename =~ s/[^a-zA-Z0-9_-]//g;

				print "I'm going to call it $filename\n";

				my $filenameDir;

				# If the submission contains an @-sign, hide it into the admin dir
				if (index($message, "@") != -1) {
					$filenameDir = "$SCRIPTDIR/admin/";

					print "I'm going to put $filename into $filenameDir because it contains an @";
				} else {
					# Prefix for new text posts
					$filenameDir = $HTMLDIR . $submitTarget;

					print "I'm going to put $filename into $filenameDir\n";
				}

				# Make sure we don't clobber an existing file
				# If filename exists, add (1), (2), and so on
				my $filename_root = $filename;
				my $i = 0;
				while (-e $filenameDir . $filename . ".txt") {
					$i++;
					$filename = $filename_root . " (" . $i . ")";
				}
				$filename .= '.txt';

				# Try to write to the file, exit if we can't
				PutFile($filenameDir . $filename, $message) or die('Could not open text file to write to '.$filenameDir . $filename);

				# Add the file to git
				system("git add $filenameDir$filename");

				print "git add $filenameDir$filename\n";
			}
		}

		# If the URL begins with "/action/" run it through the processor
		my $actionPrefix = "/action/";
		if (substr($file, 0, length($actionPrefix)) eq $actionPrefix) {
			print "Found an action...";

			# Put the arguments into an array
			my @actionArgs = split("/", $file);

			if ($actionArgs[2] eq 'test') {
				print "Test successful\n";
			}

			if ($actionArgs[2] eq 'tag') {
				print "tag";

				my @tagArgs = split('\?', $file);

				print $tagArgs[1];
			}
		}


	}

	# Close the log file handle
	close(LOGFILE);

	# Truncate the log file
	truncate $logfile, 0;
}

# Process the two access logs
ProcessAccessLog($LOGFILE, 0);
#ProcessAccessLog($LOGFILE_VHOST, 1);

1;
