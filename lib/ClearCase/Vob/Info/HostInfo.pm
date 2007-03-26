# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/HostInfo.pm
# Desc:  Information from the "ct hostinfo -l" command
# Auth:  Chris Cobb
# Date:  Thu May 15 17:36:48 2003
# Stat:  Prototype
#
# Synopsis:
#        use ClearCase::Vob::Info::HostInfo;
#
#        $objRef = new ClearCase::Vob::Info::HostInfo( @text );
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
# When the "@text" buffer contains output from the cleartool command
#    "ct hostinfo -l"
# this will return an "ClearCase::Vob::Info::HostInfo" object.
#

package ClearCase::Vob::Info::HostInfo;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.03';
 @ISA     = qw( ClearCase::Vob::Info::InfoBase );

 use ClearCase::Vob::Info::InfoBase;
#use Date::Parse;                    # str2time( "date string" );
#use Date::Format;                   # time2str( "%c", $time   );


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

	if (/^Client: (.*)/) {
	    $self->{client}   = $1;

	   ($self->{clienthostname}) = gethostbyname( $1 );   # is this useful?

	} elsif (/^  Product: ([^\s]*) (.*)/) {
	    $self->{product} = $1;
	    $self->{version} = $2;

	} elsif (/^  Operating system: (.*)/) {
	    $self->{opsys} = $1;

	} elsif (/^  Hardware type: (.*)/) {
	    $self->{hardware} = $1;

	} elsif (/^  Registry host: (.*)/) {
	    $self->{registryhost} = $1;

	} elsif (/^  Registry region: (.*)/) {
	    $self->{registryregion} = $1;

	} elsif (/^  License host: (.*)/) {
	    $self->{licensehost} = $1;

	   ($self->{licensehostname}) = gethostbyname( $1 );  # is this useful?

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
