#!/usr/bin/perl

use strict;
use utf8;

use URI::Encode qw(uri_decode);
use URI::Escape;
use HTML::Entities;

# Gets the contents of a file
sub GetFile {
	my $fileName = shift;
	
	my $length = shift || 1048576;
	# default to reading a max of 1MB of the file. #scaling

	if (open (my $file, "<", $fileName)) {
		read ($file, my $return, $length);
		return $return;
	}
	
	return;
}

# Writes to a file
sub PutFile {
	my $file = shift;
	my $content = shift;
	
	if (open (my $fileHandle, ">", $file)) {
		print $fileHandle $content;
		close $fileHandle;
	}
}

# Appends line to a file
sub AppendFile {
	my $file = shift;
	my $content = shift;
	
	if (open (my $fileHandle, ">>", $file)) {
		say $fileHandle $content;
		close $fileHandle;
	}
}

#Trims a string
sub trim {
	my $s = shift; $s =~ s/^\s+|\s+$//g; return $s
};

# GpgParse
# $filePath = path to file containing the text
# returns a hash of {key, txt, isSigned(0/1)}
sub GpgParse {
	my $filePath = shift;
	
	my $txt = trim(GetFile($filePath));

	my $isSigned = 0;
	
	my $gpg_key;
	
	# This is where we check for a GPG signed message and sort it accordingly
	my $gpg_header = "-----BEGIN PGP SIGNED MESSAGE-----";

	# If there is a GPG header...
	if (substr($txt, 0, length($gpg_header)) eq $gpg_header) {
		# Verify the file by using command-line gpg
		# --status-fd 1 makes gpg output to STDOUT using a more concise syntax
		my $gpg_result = `gpg --verify --status-fd 1 "$filePath"`;
		
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

			$txt = `gpg --decrypt "$filePath"`;
			
			$isSigned = 1;
		}
	}
	
	my %returnValues;
	
	$returnValues{'isSigned'} = $isSigned;
	$returnValues{'text'} = $txt;
	$returnValues{'key'} = $gpg_key;
	
	return %returnValues;
}

1;
