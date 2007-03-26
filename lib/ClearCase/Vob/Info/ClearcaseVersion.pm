# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/ClearcaseVersion.pm
# Desc:  Parse output of "ct -version" and "ct -verall" commands
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#

package ClearCase::Vob::Info::ClearcaseVersion;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.02';
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

    # Handle both an array of text strings
    # and a single multi-line text string
    #
    $#text == 0 and (@text) = split("\n", $text[0]);

    # Handle both ClearCase and MultiSite here. Also, make darn
    # SURE that any subsequent match tests for "$text[0]" don't
    # break any prior tests!
    #
    my($app,$ver,$base,$date);

    if ($text[0] =~ /^(ClearCase|MultiSite) version ([^\s]*) \(([^)]*)\)$/) {

	($app,$base,$date) = ($1,$2,$3);                    # Version 6
	($ver) = $base =~ /\d{4}\.0?(.+)/;

    } elsif ($text[0] =~ /(ClearCase|MultiSite) version ([^\s]*) \(([^)]*)\) \(([^)]*)\)/) {

	($app,$ver,$base,$date) = ($1,$2,$3,$4);            # Version 5, 4

    } else {
	$self->setErr(-1,"Unable to parse: '$text[0]'");
	$self->addUnparsed( $text[0] );
    }

    $self->{app}     = $app;      # either "ClearCase" or "MultiSite"
    $self->{base}    = $base;     # e.g.,  "2001A.04.00"  or "2003.06.00"
    $self->{version} = $ver;      # e.g.,  "4.2"          or "6.00"
    $self->{date}    = $date;     # e.g.,  "Wed Apr 11 11:40:11 EDT 2001"
    $self->{list}    = \@text;    # contains full "-ver" or "-verall" output

    #print "DEBUG: text='$text[0]'\n";
    #print "DEBUG: app='$app'  base='$base'  ver='$ver'  date='$date'\n";
    #die $self->dump;

    return $self;
}
#_________________________
1; # Required by require()
