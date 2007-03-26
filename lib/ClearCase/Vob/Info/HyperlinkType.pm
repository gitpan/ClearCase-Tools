# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/HyperlinkType.pm
# Desc:  Information about a VOB hyperlink
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#
# Synopsis:
#        use ClearCase::Vob::Info::HyperlinkType;
#
#        $objRef = new ClearCase::Vob::Info::HyperlinkType( @text );
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
# When the "@text" buffer contains output from the cleartool commands
#    "ct describe -l hlink:Type@HlinkID@/vobtag"
# this will return an "ClearCase::Vob::Info::HyperlinkType" object.
#

package ClearCase::Vob::Info::HyperlinkType;
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

    # Here we parse the output from "ct des -l hlink:HlinkDef"
    # This class is intended to be instantiated via the
    # "ClearCase::Vob::Info" class
    #
    # Handle both an array of text strings
    # and a single multi-line text string
    #
    $#text == 0 and (@text) = split("\n", $text[0]);

    my $inComment = 0;

    foreach (@text) {
	#print "DEBUG: $_\n";

	if (/^  master replica: (.*)/) {
	    my $masterReplica      = $1;
	    $self->{masterReplica} = $masterReplica;

	    if ( $masterReplica =~ /\s*([^@]*)@(.*)$/) {
		$self->{masterReplicaVob}    = $1;
		$self->{masterReplicaVobTag} = $2;
	    }

	    # Whew ... parsing comments like this sucks!
	    # If there is a comment, strip the trailing '"' char.
	    # but only do this ONCE.
	    if ($inComment and $self->{comment}) { $self->{comment} =~ s#"$##; }
	    $inComment = 0;

	} elsif ($inComment) {
	    my($comment) = $_ =~ /^   (.*)$/;
	    $comment ||= "";
	    $self->{comment} .= "\n$comment";

	} elsif (/^hyperlink "([^"]*)?/) {
	    $self->{object_name} = $1;

	} elsif (/^  created (\d\d)-(\w\w\w)-(\d\d?\d?)\.(\d\d:\d\d:\d\d) by (.*)/) {
	    my $day = $1;
	    my $mon = $2;
	    my $year = $3;
	    my $time = $4;
	    my($epoch) = str2time("$day/$mon/$year $time") || 0;

	    $self->{createDate} = $epoch ? time2str( "%c", $epoch ) : "Unknown";
	    $self->{_createStamp} = $epoch || 0;
	    $self->{creator}= $5;

	} elsif (/^  owner: (.*)/) {
	    my $owner = $1;
	    $owner =~ s#^UNIX:UID-##;
	    $self->{owner} = $owner;

	    # Whew ... parsing comments like this sucks!
	    # If there is a comment, strip the trailing '"' char.
	    # but only do this ONCE.
	    if ($inComment and $self->{comment}) { $self->{comment} =~ s#"$##; }
	    $inComment = 0;

	} elsif (/^  group: (.*)/) {
	    my $group = $1;
	    $group =~ s#^UNIX:GID-##;
	    $self->{group} = $group;

	# Note: this assumes that a hyperlink definition is
	#       always stored in "Source -> Target" format:
	#       
	} elsif (/^\s*([^\s]*)\s*([^\s]*)\s*->\s*(.*)$/) {
	    $self->{name}    = $1;
	    $self->{source}  = $2;
	    $self->{target}  = $3;
	  ( $self->{_type} ) = $1 =~ /^([^@]*)/;

	} elsif (/^  "(.*)/) {
	    $self->{comment} = $1;
	    $inComment = 1;

	#______________________________________________________
	# Unknown input
	} else {
	    $self->addUnparsed( $_ );
	}
    }
    $self->{count} = 1;

    return $self;
}
#_________________________
1; # Required by require()
