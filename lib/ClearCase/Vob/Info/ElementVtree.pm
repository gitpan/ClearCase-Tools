# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/ElementVtree.pm
# Desc:  Information about versionso of an element
# Auth:  Chris Cobb
# Date:  Fri Jan 11 14:03:31 2002
# Stat:  Prototype
#
# ToDo:  Convert this into "::VtreeList" and "::VtreeType" classes?
#        If so, modify the "::Info" class that loads this module.
#
# WARN:  This simple parsing omits the following pieces
#        .  labels
#        .  views for CHECKEDOUT elements
#        .  hyperlink "arrows"
#        Use "Info::Dump" or "Info::ElementType" classes for this info.
#        Also note that branches are left intermingled with elem versions
#        to allow proper branch sequencing when processing all elem vers.
#
# Synopsis:
#        use ClearCase::Vob::Info::ElementVtree;
#
#        $objRef = new ClearCase::Vob::Info::ElementVtree( @text );
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
#    "ct -all -merge -obsolete $element"
# this will return an "ClearCase::Vob::Info::ElementVtree" object.
#

package ClearCase::Vob::Info::ElementVtree;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.01';
 @ISA     = qw( ClearCase::Vob::Info::InfoBase );

 use ClearCase::Vob::Info::InfoBase;
#use Date::Parse;                    # str2time( "date string" );
#use Date::Format;                   # time2str( "%c", $time   );

 use ClearCase::Vob::Info::ElementType;
#use ClearCase::Vob::Info::HyperlinkType;
 use ClearCase::Vob::Info::LabelType;

 my $ElementClass   = "ClearCase::Vob::Info::ElementType";
#my $HyperlinkClass = "ClearCase::Vob::Info::HyperlinkType";
 my $LabelClass     = "ClearCase::Vob::Info::LabelType";

# WARN:  Defining additional methods here should be done with care!!
#        Any methods here not available to ALL classes that have an
#        inheritance relationship to "ClearCase::Vob::Info::InfoBase"
#        violates some basic OO design tenets.

sub new
{   my($class,@text) = @_;

    bless my $self = {}, ref($class)||$class;
    $self->setErr(0,"");

    # Here we parse the output from "ct lsvtree ..."
    # This class is intended to be instantiated via the
    # "ClearCase::Vob::Info" class
    #
    # Handle both an array of text strings
    # and a single multi-line text string
    #
    $#text == 0 and (@text) = split("\n", $text[0]);

    #print "$PACK DEBUGGING -----------\n";

    my($element,$branch,$version,$labels) = ("","","","");
    my($elemVer,$elemBranch,$view,@labels) = ("","","",());
  # my $hyperLninks = {};
    my $count = 0;

    # WARN: This simple parsing omits the following pieces
    #       .  labels
    #       .  views for CHECKEDOUT elements
    #       .  hyperlink "arrows"
    #
    # Use "Info::Dump" or "Info::ElementType" classes for this info

    foreach (@text) {
	#print "\n ORIG: '$_'\n";

        if (/^  (<-|->) (.*)/) {
	    # When encountering hyperlinks, correlate them with the
	    # last prior "$element" or, if none, we can't parse it.
	    # FIX: use a HASH here, but link it to the $element (how?)
	    #
	  # if ($element) {
	  #	$self->addUnparsed( $_ );
	  # } else {
		$self->addUnparsed( $_ );
	  # }

	} elsif (m#\@#) {

	    if (m# \(([^(]*)\)$#) {
		$labels  = $1;
		$element = $_;
		$element =~ s# \($labels\)##;

		$self->addList(undef, $element);

	        # FIX: link $labels to this $element version (how?)
		## $self->addUnparsed( $labels );

	    } elsif (m# view "([^"]*)"$#) {
		$view    = $1;
		$element = $_;
		$element =~ s# view "$view"##;

		$self->addList(undef, $element);

	        # FIX: link $view to this $element version (how?)
		## $self->addUnparsed( $view );

	    } else {
		$self->addList(undef, $_);
	    }
	    $count++;

	#______________________________________________________
	# Unknown input
	} else {
	    $self->addUnparsed( $_ );
	}

    }
    $self->{count} = $count;

    return $self;
}
#_________________________
1; # Required by require()
