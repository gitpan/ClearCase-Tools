# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/List.pm
# Desc:  Default Class for ClearCase::Vob::Info::<module> classes
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#

package ClearCase::Vob::Info::List;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.03';
 @ISA     = qw( ClearCase::Vob::Info::InfoBase );

 use ClearCase::Vob::Info::InfoBase;


# WARN:  Defining additional methods here should be done with care!!
#        Any methods here not available to ALL classes that have an
#        inheritance relationship to "ClearCase::Vob::Info::InfoBase"
#        violates some basic OO design tenets.

sub new
{   my($class,@text) = @_;

    bless my $self = {}, ref($class)||$class;
    $self->setErr(0,"");

    if (scalar @text and $#text > -1) {
	# Handle both an array of text strings
	# and a single multi-line text string
	#
	if ($#text == 0 and defined $text[0]) {
	    (@text) = split("\n", $text[0])
	}
	$self->{list}  = \@text;
	$self->{count} = $#text + 1;
    }
    $self->setUnknown;

    return $self;
}
#_________________________
1; # Required by require()
