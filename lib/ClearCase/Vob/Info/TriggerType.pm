# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/TriggerType.pm
# Desc:  Information about a VOB trigger
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#
# Synopsis:
#        use ClearCase::Vob::Info::TriggerType;
#
#        $objRef = new ClearCase::Vob::Info::TriggerType( @text );
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
# this will return an "ClearCase::Vob::Info::TriggerType" object.
#

package ClearCase::Vob::Info::TriggerType;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.01';
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

    # Here we parse the output from "ct lstype -l ..."
    # This class is intended to be instantiated via the
    # "ClearCase::Vob::Info" class
    #
    # Handle both an array of text strings
    # and a single multi-line text string
    #
    $#text == 0 and (@text) = split("\n", $text[0]);

    foreach (@text) {
	#print "DEBUG: $_\n";

	if (/^trigger type "([^"]*)"/) {
	    $self->{name} = $1;

        #    "ct lstype -kind trtype"
	} elsif (/^  created (\d\d)-(\w\w\w)-(\d\d?\d?)\.(\d\d:\d\d:\d\d) by (.*)/) {
	    my $day = $1;
	    my $mon = $2;
	    my $year = $3;
	    my $time = $4;
	    my($epoch) = str2time("$day/$mon/$year $time") || 0;

	    $self->{createDate} = $epoch ? time2str( "%c", $epoch ) : "Unknown";
	    $self->{_createStamp} = $epoch || 0;
	    $self->{creatorName}= $5;

        #    "ct describe -l trtype:xx"
	} elsif (/^ (\d\d)-(\w\w\w)-(\d\d?\d?)\.(\d\d:\d\d:\d\d) by (.*)/) {
	    my $day = $1;
	    my $mon = $2;
	    my $year = $3;
	    my $time = $4;
	    my($epoch) = str2time("$day/$mon/$year $time") || 0;

	    $self->{createDate} = $epoch ? time2str( "%c", $epoch ) : "Unknown";
	    $self->{_createStamp} = $epoch || 0;
	    $self->{creatorName}= $5;

	# FIX: Handle multiple comment lines (see ElementType.pm)
	} elsif (/^  "([^"]*)"/) {
	    $self->{comment} = $1;

	} elsif (/^  owner: (.*)/) {
	    $self->{owner} = $1;

	} elsif (/^  group: (.*)/) {
	    $self->{group} = $1;

	} elsif (/^  element (.*)/) {
	    $self->{element} = $1;

	} elsif (/^  post-operation (.*)/) {
	    $self->{'postoperation'} = $1;

	} elsif (/^  action: (.*)/) {
	    $self->{action} = $1;

	} elsif (/^  restriction: (.*)/) {
	    $self->{restriction} = [] 
		unless defined $self->{restriction};
	    push @{ $self->{restriction} }, $1;

	# FIX: What other "types" of text will we encounter?  ;-(
	#
	} elsif (/^  (all element trigger)/) {
	    $self->{type} = $1;

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
