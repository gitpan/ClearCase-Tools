# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/VersionedObjectBase.pm
# Desc:  Information about a VOB 
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#
# Synopsis:
#        use ClearCase::Vob::Info::VersionedObjectBase;
#
#        $objRef = new ClearCase::Vob::Info::VersionedObjectBase( @text );
#
# However, the intended usage is somewhat different from the synopsis.
# This module is one of several ClearCase/MultiSite "info" classes that
# parse output from the various cleartool/multitool commands into objects.
#
# Intended Usage:
#        use ClearCase::Vob::Info;
#
#        $objRef = new ClearCase::Vob::Info( @text );
#      
# When the "@text" buffer contains output from the "ct lsvob" command,
# this will return an "ClearCase::Vob::Info::VersionedObjectBase" object.
#

package ClearCase::Vob::Info::VersionedObjectBase;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.03';
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

    bless my $self = {}, ref($class)||$class;
    $self->setErr(0,"");

    # Here we parse the output from "ct lsvob -l "
    # This class is intended to be instantiated via the
    # "ClearCase::Vob::Info" class
    #
    # Handle both an array of text strings
    # and a single multi-line text string
    #
    $#text == 0 and (@text) = split("\n", $text[0]);

    my($inVobOwner,$inAddGroups,$inHyperln,$inViews) = (0,0,0,0);

    foreach (@text) {
	#print "DEBUG: $_\n";

	#______________________________________________________
	# MultiSite VOB   --  ct version ??
	#
	if (/^versioned object base "([^"]*)(" \(locked\))?/) {
	    $self->{_vobType}="Replicated";
	    $self->{vobName} = $1;

	    $self->setLocked if $2;

	} elsif (/^  created (\d\d)-(\w\w\w)-(\d\d?\d?)\.(\d\d:\d\d:\d\d) by (.*)/) {
	    my $day    = $1;
	    my $mon    = $2;
	    my $year   = $3;
	    my $time   = $4;
	    my $cname  = $5;
	    my($epoch) = str2time("$day/$mon/$year $time") || 0;

	    $self->{createDate} = $epoch ? time2str( "%c", $epoch ) : "Unknown";
	    $self->{_createStamp} = $epoch || 0;
	    $self->{creatorFullName}= $cname;

	    if ($cname =~ m#([^(]*)\(([^.]*)\.([^@]*)@([^)]*)\)#) {
		chop(my $creatorName = $1);   # strip trailing space
		$self->{creatorName} = $creatorName;
		$self->{creatorUname}= $2;
		$self->{creatorGroup}= $3;
		$self->{creatorHost} = $4;
	    }

	} elsif (/^  "([^"]*)"/) {
	    $self->{replicaComment} = $1;

	} elsif (/^  master replica: (.*)/) {
	    $self->{masterReplica}       = $1 .'@'. $2;
	    $self->{masterReplicaVob}    = $1;
	    $self->{masterReplicaVobTag} = $2;

	} elsif (/^  replica name: (.*)/) {
	    $self->{replicaName} = $1;

	} elsif (/^  VOB family feature level: (\d*)/) {
	    $self->{featureLevel} = $1;

	} elsif (/^  VOB storage host:pathname "([^"]*)"/) {
	    $self->{hostPathname} = $1;

	} elsif (/^  VOB storage global pathname "([^"]*)"/) {
	    $self->{globalPathname} = $1;

	} elsif (/^  database schema version: (\d*)/) {
	    $self->{schemaVersion} = $1;

	} elsif (/^  VOB ownership:/) {
	    ($inVobOwner,$inAddGroups,$inHyperln,$inViews) = (1,0,0,0);

	} elsif (/^  Additional groups:/) {
	    ($inVobOwner,$inAddGroups,$inHyperln,$inViews) = (0,1,0,0);

	} elsif (/^  Hyperlinks:/) {
	    ($inVobOwner,$inAddGroups,$inHyperln,$inViews) = (0,0,1,0);

	} elsif (/^  VOB holds objects from the following views:/) {
	    ($inVobOwner,$inAddGroups,$inHyperln,$inViews) = (0,0,0,1);

	} elsif (/^    owner (.*)/) {
	    $self->{vobOwner} = $1;

	} elsif (/^    group (.*)/) {
	    $inVobOwner  and $self->{vobGroup} = $1;

	    # FIX: confirm that this works correctly:
	    #
	    $inAddGroups and $self->addList("addGroup", $1);

	} elsif (/^    ([^\s]*) (<-|->) (.*)/) {
	    $inHyperln and $self->addHash("hyperLinks", $1, $3);

	} elsif (/^    ([^:]*):([^\s]*) \[uuid ([^\]]*)\]/) {
	    $inViews and $self->addHash("viewObjects", "$1:$2", $3);

	#______________________________________________________
	# Non-Replicated VOB  -- ct version 4.2  Schema 54
	#
	} elsif (/^Tag:\s*(.*)/) {
	    $self->{_vobType}="Non-Replicated";
	    $self->{vobName} = $1;

	} elsif (/^  Global path:\s*(.*)/) {
	    $self->{globalPath} = $1;

	} elsif (/^  Server host:\s*(.*)/) {
	    $self->{serverHost} = $1;

	} elsif (/^  Access:\s*(.*)/) {
	    $self->{access} = $1;

	} elsif (/^  Mount options:\s*(.*)/) {
	    $self->{mountOptions} = $1;

	} elsif (/^  Region:\s*(.*)/) {
	    $self->{region} = $1;

	} elsif (/^  Active:\s*(.*)/) {
	    $self->{active} = $1;

	} elsif (/^  Vob tag replica uuid:\s(.*)/) {
	    $self->{vobTagReplicaUuid} = $1;

	} elsif (/^Vob on host:\s(.*)/) {
	    $self->{vobOnHost} = $1;

	} elsif (/^Vob server access path:\s*(.*)/) {
	    $self->{vobServerAccessPath} = $1;

	} elsif (/^Vob family uuid:\s*(.*)/) {
	    $self->{vobFamilyUuid} = $1;

	} elsif (/^Vob replica uuid:\s*(.*)/) {
	    $self->{vobReplicaUuid} = $1;

	} elsif (/^  Attributes:/) {
	    next;

	} elsif (/^    FeatureLevel = (\d*)/) {
	    $self->{featureLevelAttribute} = $1;

	} elsif (/^\s*$/) {        # ignore trailing empty line
	    next;

	#______________________________________________________
	# Unknown input

	} else {
	    $self->addUnparsed( $_ );
	}
    }
    return $self;
}
#_________________________
1; # Required by require()
