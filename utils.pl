#!/usr/bin/perl

use strict;
use utf8;
use 5.010;

use lib 'inc';

use URI::Encode qw(uri_decode);
use URI::Escape;
use HTML::Entities;
use Storable;

sub GetHash {
	my $fileName = shift;

	my $gitOutput = `git hash-object -w "$fileName"`;

	chomp($gitOutput);

	return $gitOutput;
}

# We'll use pwd for for the install root dir
my $SCRIPTDIR = "/home/ilya/duct"; #hardcode #todo
chomp $SCRIPTDIR;

# Gets template from template dir
# Should not fail
sub GetTemplate {
	my $filename = shift;

	chomp $filename;
	$filename = "$SCRIPTDIR/template/$filename";

	return GetFile($filename);

	die("GetTemplate failed, something is probably wrong");
}

sub GetAvatar {
	my $gpg_key = shift;
	chomp $gpg_key;
	
	#todo proper sanitizing, length and char content
	
	my $color1 = substr($gpg_key, 0, 6);
	my $color2 = substr($gpg_key, 5, 6);
	my $color3 = substr($gpg_key, 10, 6);
	
	my $avatar = "<span class=avatar style=\"background-color: $color1;\">";
	$avatar .=   "<font color=\"$color2\">&bull;</font>";
	$avatar .=   "<font color=\"$color3\">&bull;</font>";
	$avatar .=   "</span>";
	
	return $avatar;
}


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


sub GetAdminKey {
	#Returns admin's key sig, 0 if there is none
	
	state $adminsKey = 0;
	
	if ($adminsKey) {
		return $adminsKey;
	}
	
	if (-e "$SCRIPTDIR/admin.key") {
	
		my %adminsInfo = GpgParse("$SCRIPTDIR/admin.key");
		
		if ($adminsInfo{'isSigned'}) {
			if ($adminsInfo{'key'}) {
				$adminsKey = $adminsInfo{'key'};
				
				return $adminsKey;
			} else {
				return 0;
			}
		} else {
			return 0;
		}
	} else {
		return 0;
	}
	
	return 0;
}
	

sub GpgParse {
	# GpgParse
	# $filePath = path to file containing the text
	#
	# $returnValues{'isSigned'} = whether the message has a valid signature: 0 or 1 for valid signature
	# $returnValues{'text'} = message text without framing
	# $returnValues{'key'} = fingerprint of signer
	# $returnValues{'alias'} = alias of signer, if they've added one by submitting their public key
	# $returnValues{'keyExpired'} = whether the key has expired: 0 for not expired, 1 for expired
	# $returnValues{'gitHash'} = 
	my $filePath = shift;

	my $txt = trim(GetFile($filePath));

	my $isSigned = 0;

	my $gpg_key;

	my $alias;

	my $keyExpired = 0;

	my $gitHash = GetHash($filePath);

	if (-e $filePath . ".cache") {
		my %returnValues = %{retrieve($filePath . ".cache")};

		return %returnValues;
	}

	# Signed messages begin with this header
	my $gpg_message_header = "-----BEGIN PGP SIGNED MESSAGE-----";

	# Public keys (that set the username) begin with this header
	my $gpg_pubkey_header = "-----BEGIN PGP PUBLIC KEY BLOCK-----";

	# This is where we check for a GPG signed message and sort it accordingly
	#########################################################################

	# If there is a GPG pubkey header...
	if (substr($txt, 0, length($gpg_pubkey_header)) eq $gpg_pubkey_header) {
		my $gpg_result = `gpg --keyid-format LONG "$filePath"`;

		foreach (split ("\n", $gpg_result)) {
			chomp;
			if (substr($_, 0, 4) eq 'pub ') {
				my @split = split(" ", $_, 4);
				$alias = $split[3];
				$gpg_key = $split[1];

				@split = split("/", $gpg_key);
				$gpg_key = $split[1];

				$txt = "The key fingerprint $gpg_key has been aliased to \"$alias\"\n";

				$isSigned = 1;

				#print $gpg_key;
			}
		}
	}

	# If there is a GPG header...
	if (substr($txt, 0, length($gpg_message_header)) eq $gpg_message_header) {
		# Verify the file by using command-line gpg
		# --status-fd 1 makes gpg output to STDOUT using a more concise syntax
		my $gpg_result = `gpg --verify --status-fd 1 "$filePath"`;

		my $key_id_prefix;
		my $key_id_suffix;

		if (index($gpg_result, "[GNUPG:] NO_PUBKEY ") >= 0) {
			$key_id_prefix = "[GNUPG:] NO_PUBKEY ";
			$key_id_suffix = "\n";
		}

		if (index($gpg_result, "[GNUPG:] GOODSIG ") >= 0) {
			$key_id_prefix = "[GNUPG:] GOODSIG ";
			$key_id_suffix = " ";
		}

		if (index($gpg_result, "[GNUPG:] EXPKEYSIG ") >= 0) {
			$key_id_prefix = "[GNUPG:] EXPKEYSIG ";
			$key_id_suffix = " ";

			$keyExpired = 1;
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
	$returnValues{'alias'} = $alias;
	$returnValues{'keyExpired'} = $keyExpired;
	$returnValues{'gitHash'} = $gitHash;

	store \%returnValues, $filePath . ".cache";

	return %returnValues;
}

1;
