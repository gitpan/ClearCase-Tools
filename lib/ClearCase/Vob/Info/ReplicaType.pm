# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/ReplicaType.pm
# Desc:  Container for VOB Replica information
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#
# Note:  Objects of this class are intended to be instantiated
#        by the "ClearCase::Vob::Info::ReplicaList" class
#
# Synopsis:
#        use ClearCase::Vob::Info::ReplicaType;
#
#        $replRef  = new ClearCase::Vob::Info::ReplicaType( $textstring );
#
#        $replName = $replRef->name;
#        $replHost = $replRef->host;
#        $replMstr = $replRef->master;
#        ... etc.
#

package ClearCase::Vob::Info::ReplicaType;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.04';
 @ISA     = qw( ClearCase::Vob::Info::InfoBase );

 use ClearCase::Vob::Info::InfoBase;
 use Date::Parse;                    # str2time( "date string" );
 use Date::Format;                   # time2str( "%c", $time   );


# WARN:  Defining additional methods here should be done with care!!
#        Any methods here not available to ALL classes that have an
#        inheritance relationship to "ClearCase::Vob::Info::InfoBase"
#        violates some basic OO design tenets.

sub new
{   my($class,@text) = @_;

    my $self = bless {}, ref($class)||$class;

    $self->setErr(0,"");                  # Reset any prior error condition

    # Here we parse the output from "ct lsreplica -l "
    # This class is intended to be instantiated via the
    # "ClearCase::Vob::Info::ReplicaList" class
    #
    # Handle both an array of text strings
    # and a single multi-line text string
    #
    $#text == 0 and (@text) = split("\n", $text[0]);

    foreach (@text) {
	#print "$PACK DEBUG: $_\n";

	if (/^For VOB replica "([^"]*)":/) {
	    $self->{family} = $1;

	} elsif (/^replica "([^"]*)"/) {
	    $self->{name} = $1;

	} elsif (/^ (\d\d)-(\w\w\w)-(\d\d?\d?)\.(\d\d:\d\d:\d\d) by (.*)/) {
	    my $day = $1;
	    my $mon = $2;
	    my $year = $3;
	    my $time = $4;
	    my($epoch) = str2time("$day/$mon/$year $time") || 0;

	    $self->{createDate} = $epoch ? time2str( "%c", $epoch ) : "Unknown";
	    $self->{createStamp} = $epoch || 0;
	    $self->{creator}= $5;

	} elsif (/^  "([^"]*)"/) {
	    $self->{comment} = $1;

	} elsif (/^  replica type: (.*)/) {
	    $self->{type} = $1;

	} elsif (/^  master replica: (.*)/) {
	    $self->{master} = $1;

	} elsif (/^  request for mastership: (.*)/) {
	    $self->{requestMaster} = $1;

	} elsif (/^  owner: (.*)/) {
	    $self->{owner} = $1;

	} elsif (/^  group: (.*)/) {
	    $self->{group} = $1;

	} elsif (/^  host: "([^"]*)"/) {
	    $self->{host} = $1;

	} elsif (/^  feature level: (.*)/) {
	    $self->{featurelevel} = $1;

	} elsif (/^  identities: (.*)/) {      # V4.x
	    $self->{identities} = $1;

	} elsif (/^  connectivity: (.*)/) {    # V5.x
	    $self->{connectivity} = $1;

	} elsif (/^  permissions: (.*)/) {     # V6.x
	    $self->{permissions} = $1;

        #    "mt xxxx"
	} elsif (/^ (\d\d)-(\w\w\w)-(\d\d?\d?)\.(\d\d:\d\d:\d\d) by (.*)/) {
	    my $day = $1;
	    my $mon = $2;
	    my $year = $3;
	    my $time = $4;
	    my($epoch) = str2time("$day/$mon/$year $time") || 0;

	    $self->{createDate} = $epoch ? time2str( "%c", $epoch ) : "Unknown";
	    $self->{createStamp} = $epoch || 0;
	    $self->{creator}= $5;

        #    "mt yyyy"
	} elsif (/^  created (\d\d)-(\w\w\w)-(\d\d?\d?)\.(\d\d:\d\d:\d\d) by (.*)/) {
	    my $day = $1;
	    my $mon = $2;
	    my $year = $3;
	    my $time = $4;
	    my($epoch) = str2time("$day/$mon/$year $time") || 0;

	    $self->{createDate} = $epoch ? time2str( "%c", $epoch ) : "Unknown";
	    $self->{createStamp} = $epoch || 0;
	    $self->{creator}= $5;

	} elsif (/^  Attributes:/) {
	    next;

	} elsif (/^    FeatureLevel = (\d*)/) {
	    next;
	    #$self->{featurelevel} = $1;         # duplicate attribute
	#______________________________________________________
	# Unknown input
	} else {
	    $self->addUnparsed( $_ );
	}
    }

    return($self,$self->{STATUS},$self->{ERROR}) if wantarray;
    return $self;
}
#_________________________
1; # Required by require()
