# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/ReplicaList.pm
# Desc:  Information about one/some/all replicas in a VOB famlily
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#
# Synopsis:
#        use ClearCase::Vob::Info::ReplicaList;
#
#        $objRef = new ClearCase::Vob::Info::ReplicaList( @text );
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
# When the "@text" buffer contains output from the "ct lsreplica" command,
# this will return an "ClearCase::Vob::Info::ReplicaList" object that
# contains one or more "ClearCase::Vob::Info::ReplicaType" objects.
#

package ClearCase::Vob::Info::ReplicaList;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.03';
 @ISA     = qw( ClearCase::Vob::Info::InfoBase );

 use ClearCase::Vob::Info::InfoBase;
 use ClearCase::Vob::Info::ReplicaType;

 my $TypeClass = "ClearCase::Vob::Info::ReplicaType";


# WARN:  Defining additional methods here should be done with care!!
#        Any methods here not available to ALL classes that have an
#        inheritance relationship to "ClearCase::Vob::Info::InfoBase"
#        violates some basic OO design tenets.

sub new
{   my($class,@text) = @_;

    bless my $self = {}, ref($class)||$class;
    $self->setErr(0,"");

    # Here we parse the output from "ct lsreplica -l "
    # This class is intended to be instantiated via the
    # "ClearCase::Vob::Info::ReplicaList" class
    #
    # Handle both an array of text strings
    # and a single multi-line text string
    #
    $#text == 0 and (@text) = split("\n", $text[0]);

    my $replicaName = "";
    my $inReplica = 0;
    my(@subText) = ();

    $self->{list} = [];

    foreach (@text) {
	#print "$PACK DEBUG: $_\n";

	if (/^For VOB replica "([^"]*)":/) {
	    $self->{replicaFamily} = $1;

	} elsif (/^  master replica: (.*)/) {
	    $self->{masterReplica} = $1;

	} elsif (/^replica "([^"]*)"/) {
	    # Here we allow for the parsing of multiple replica
	    # entries, e.g., from "lsreplica -l -invob VobTag"
	    #
	    if ($inReplica) {
	    	push @{ $self->{list} }, $replicaName;
		$self->{$replicaName} = $TypeClass->new( @subText );
		(@subText) = ();
	    }
	    $replicaName = $1;
	    $inReplica   = 1;
	    push @subText, $_;

	} else {
	    push @subText, $_;
	}
    }
    # Here we handle either a single replica's info or the
    # last replica from text containing multiple replicas
    #
    push @{ $self->{list} }, $replicaName;
    $self->{$replicaName} = $TypeClass->new( @subText );

    $self->{count} = $#{ $self->{list} } + 1;
    return $self;
}
#_________________________
1; # Required by require()
