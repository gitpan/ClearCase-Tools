# -*- Perl -*-
#
# File:  ClearCase/View/Info/ViewList.pm
# Desc:  Information about a View 
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#
# Synopsis:
#        use ClearCase::View::Info::ViewList;
#
#        $objRef = new ClearCase::View::Info::ViewList( @text );
#
# However, the intended usage is somewhat different from the synopsis.
# This module is one of several ClearCase/MultiSite "info" classes that
# parse output from the various cleartool/multitool commands into objects.
#
# Intended Usage:
#        use ClearCase::View::Info;
#
#        $objRef = new ClearCase::View::Info( @text );
#      
# When the "@text" buffer contains output from the "ct lsview" command,
# this will return an "ClearCase::View::Info::ViewList" object.
#

package ClearCase::View::Info::ViewList;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.03';
 @ISA     = qw( ClearCase::View::Info::InfoBase );

 use ClearCase::View::Info::InfoBase;
 use ClearCase::View::Info::View;


# WARN:  Defining additional methods here should be done with care!!
#        Any methods here not available to ALL classes that have an
#        inheritance relationship to "ClearCase::Vob::Info::InfoBase"
#        violates some basic OO design tenets.

sub new
{   my($class,@text) = @_;

    bless my $self = {}, ref($class)||$class;
    $self->setErr(0,"");

    # Handle both an array of text strings
    # and a single multi-line text string
    #
    $#text == 0 and (@text) = split("\n", $text[0]);

    my $viewTag = "";
    my $inView = 0;
    my(@subText) = ();

    $self->{list} = [];

    foreach (@text) {
	#print "DEBUG: $_\n";

	if (/^Tag: (.*)/) {
	    # Here we allow for the parsing of multiple view
	    # entries, e.g., from "lsview -host `hostname` -l"
	    #
	    if ($inView) {
		push @{ $self->{list} }, $viewTag;
		$self->{$viewTag} = 
		    ClearCase::View::Info::View->new( @subText );
		(@subText) = ();
	    }
	    $viewTag = $1;
	    $inView = 1;
	    push @subText, $_;

	} elsif ( /^(\*|\s)\s(\S+)\s+(\/\S+)$/ ) {
	    # Here we allow for the parsing of multiple view
	    # entries, e.g., from "lsview -prop [-full] { viewtag | * }
	    # eg:  "* view-tag  /Storage/Dir/Path"
	    # eg:  "  view-tag  /Storage/Dir/Path"
	    #
	    if ($inView) {
		push @{ $self->{list} }, $viewTag;
		$self->{$viewTag} = 
		    ClearCase::View::Info::View->new( @subText );
		(@subText) = ();
	    }
	    $viewTag = $2;
	    $inView = 1;
	    push @subText, $_;


	} else {
	    push @subText, $_;
	}
    }
    push @{ $self->{list} }, $viewTag;
    $self->{$viewTag} = ClearCase::View::Info::View->new( @subText );

    $self->{count} = $#{ $self->{list} } + 1;

    return $self;
}
#_________________________
1; # Required by require()
