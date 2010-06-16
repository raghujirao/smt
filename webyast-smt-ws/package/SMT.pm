package YaPI::SMT;

use strict;
use YaST::YCP qw(:LOGGING);
use YaPI;
use Data::Dumper;

#textdomain ("smt");

# ------------------- imported modules
YaST::YCP::Import ("SMTData");
# -------------------------------------

our $VERSION		= '1.0.0';
our @CAPABILITIES 	= ('SLES11');
our %TYPEINFO;

=item *
C<$hash Read ();>

Returns SMT data

=cut

BEGIN{$TYPEINFO{Read} = ["function",
    [ "map", "string", "any" ]];
}
sub Read {

    my $self	= shift;
    my $ret	= {
	"credentials"	=> {
	    "NCC"	=> {},
	    "DB"	=> {},
	    "LOCAL"	=> {}
	},
	"status"	=> 0
    };

    SMTData->ReadFirstRun ();
    SMTData->ReadCredentials ();

    foreach my $entry ("NUUser", "NUPass", "NUUrl") {
	my $val	= SMTData->GetCredentials ("NU", $entry);
	$ret->{"credentials"}{"NCC"}{$entry}	= $val;
    }

    foreach my $entry ("config", "user", "pass") {
	my $val	= SMTData->GetCredentials ("DB", $entry);
	$ret->{"credentials"}{"DB"}{$entry}	= $val;
    }

    foreach my $entry ("smtUser", "MirrorTo", "nccEmail", "url", "signingKeyID", "signingKeyPassphrase") {
	my $val	= SMTData->GetCredentials ("LOCAL", $entry);
	$ret->{"credentials"}{"LOCAL"}{$entry}	= $val;
    }

    SMTData->ReadSMTServiceStatus ();
    $ret->{"status"}	= YaST::YCP::Boolean (SMTData->GetSMTServiceStatus ());

    return $ret;
}

=item *
C<$string Write ($argument_hash);>

Writes SMT settings. Returns error code.

=cut

BEGIN{$TYPEINFO{Write} = ["function",
    "integer",
    [ "map", "string", "any" ]];
}
sub Write {

    my $ret	= 0;
    my $self	= shift;
    my $args	= shift;

    SMTData->ReadFirstRun ();
    SMTData->ReadCredentials ();

    foreach my $section ("LOCAL", "DB", "NCC") {
	foreach my $key (keys %{$args->{"credentials"}{$section}}) {
	    y2security ("key $key, section $section, value: ", $args->{"credentials"}{$section}{$key});
	    SMTData->SetCredentials ("LOCAL", $key, $args->{"credentials"}{$section}{$key});
	}
    }
    $ret	= SMTData->WriteCredentials ();
    return $ret;
}
