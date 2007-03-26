# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/ElementList.pm
# Desc:  Information about one/some/all element(s) in a VOB
# Auth:  Chris Cobb
# Date:  Wed Jan 02 15:18:21 2002
# Stat:  Prototype
#
# Synopsis:
#        use ClearCase::Vob::Info::ElementList;
#
#        $objRef = new ClearCase::Vob::Info::ElementList( @text );
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
# When the "@text" buffer contains output from the "ct lstype -kind brtype"
# command, this will return an "ClearCase::Vob::Info::ElementList" object that
# contains one or more "ClearCase::Vob::Info::ElementType" objects.
#

package ClearCase::Vob::Info::ElementList;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.03';
 @ISA     = qw( ClearCase::Vob::Info::InfoBase );

 use ClearCase::Vob::Info::InfoBase;
 use ClearCase::Vob::Info::ElementType;

 my $TypeClass = "ClearCase::Vob::Info::ElementType";

# WARN:  Defining additional methods here should be done with care!!
#        Any methods here not available to ALL classes that have an
#        inheritance relationship to "ClearCase::Vob::Info::InfoBase"
#        violates some basic OO design tenets.

sub new
{   my($class,@text) = @_;

    bless my $self = {}, ref($class)||$class;
    $self->setErr(0,"");

    # Here we parse the output from "ct desc -l <element>"
    # Handle both an array of text strings
    # and a single multi-line text string
    #
    $#text == 0 and (@text) = split("\n", $text[0]);

    my $elemName = "";
    my $inElem   = 0;
    my(@subText) = ();

    $self->{list} = [];

    foreach (@text) {
	#print "$PACK DEBUG: $_\n";

	if ( (/^(directory )?(element|version) "([^"]*)"/) 
	||   (/^(file )?(element|version) "([^"]*)"/)   
	||   (/^(View) private (directory|file) "([^"]*)"/) ) {
	    # Here we allow for the parsing of multiple element
	    # entries, e.g., from "ct desc -l *"
	    #
	    if ($inElem) {
	    	push @{ $self->{list} }, $elemName;
		$self->{$elemName} = $TypeClass->new( @subText );
		(@subText) = ();
	    }
	    $elemName = $3;
	    $inElem   = 1;
	    push @subText, $_;

	} else {
	    push @subText, $_;
	}
    }
    # Here we handle either a single replica's info or the
    # last replica from text containing multiple replicas
    #
    push @{ $self->{list} }, $elemName;
    $self->{$elemName} = $TypeClass->new( @subText );

    $self->{count} = $#{ $self->{list} } + 1;
    return $self;
}
#_________________________
1; # Required by require()
