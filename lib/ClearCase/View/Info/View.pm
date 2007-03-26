# -*- Perl -*-
#
# File:  ClearCase/View/Info/View.pm
# Desc:  Information about a View 
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#
# Synopsis:
#        use ClearCase::View::Info::View;
#
#        $objRef = new ClearCase::View::Info::View( @text );
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
# this will return an "ClearCase::View::Info::View" object.
#

package ClearCase::View::Info::View;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.07';
 @ISA     = qw( ClearCase::View::Info::InfoBase );

 use ClearCase::View::Info::InfoBase;
#use Date::Parse;                    # str2time( "date string" );
 use Date::Format;                   # time2str( "%c", $time   );


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

    my $dateStringMatch = '(\d\d-\w\w\w-\d\d\d?\d?\.\d\d:\d\d:\d\d)';
    my $dateTypeMatch   = '(Created|Last modified|Last accessed|Last read of private data|Last config spec update|Last view private object update)';
    my $attrPrefixRef = {
	                        'Created' => "create",
	                  'Last modified' => "modify",
	                  'Last accessed' => "access",
	      'Last read of private data' => "privRead",
	        'Last config spec update' => "config",
	'Last view private object update' => "privObj",
		      };

    foreach (@text) {
	#print "DEBUG: $_\n";

	if (/^Tag: (.*)/) {
	    $self->{name} = $1;

	} elsif (/^  Global path: (.*)/) {
	    $self->{globalPath} = $1;

	} elsif (/^  Server host: (.*)/) {
	    $self->{host} = $1;

	} elsif (/^  Region: (.*)/) {
	    $self->{region} = $1;

	} elsif (/^  Active: (.*)/) {
	    $self->{active} = $1;

	} elsif (/^  View tag uuid:(.*)/) {
	    $self->{tagUuid} = $1;

	} elsif (/^View on host: (.*)/) {
	    $self->{viewHost} = $1;

	} elsif (/^View server access path: (.*)/) {
	    $self->{accessPath} = $1;

	} elsif (/^View uuid: (.*)/) {
	    $self->{uuid} = $1;

	} elsif (/^View owner: (.*)/) {
	    my $owner = $1;

	    $self->{owner} = $owner;

	    if ($owner =~ /([^\/]*)\/(.*)/) {
		$self->{ownerUname} = $2;
	    }

	# All of the following was added to support  "-properties [-full]" 

        # This next test supports all of the following putput lines
	#   Created ...                             createDate,   et. al
	#   Last modified ...                       modifyDate,   et. al
	#   Last accessed ...                       accessDate,   et. al
	#   Last read of private data ...           privReadDate, et. al
	#   Last config spec update ...             configUpdate, et. al
	#   Last view private object update ...     privObUpdate, et. al
	#
	} elsif (/^$dateTypeMatch $dateStringMatch by (.*)/o) {

	    my $dateType = $1;
	    my $dateStr  = $2;
	    my $creator  = $3;

	    # Work around various formats emitted by cleartool proc, e.g.:
	    #  created 26-May-00.13:08:35 by Dan Sowers (dsowers.uxdev@balboa)
	    #  created 09-Sep-99.10:28:42 by llf.uxdev@balboa

	    my($userName,$uname,$gname,$hostname) = 
		$creator =~ /^([^\(]*)\(([^.]*)\.([^@]*)\@([^\)]*)\)/;

	    if ($userName) {
		$userName =~ s/\s*$// if $userName;
	    } else {
	    	($uname,$gname,$hostname) = 
		    $creator =~ /^([^.]*)\.([^@]*)\@(.*)/;
	    }

	    my $prefix = $attrPrefixRef->{$dateType};
	    my $epoch  = $self->datestrToEpoch( $dateStr );

	    if (! $prefix) {
		$self->addUnparsed( $_ );
	    } else {
		$self->{ ${prefix}."Date"} =
		    ( $epoch ? time2str("%c",$epoch) : "Unknown" );
		$self->{ "_".${prefix}."Stamp"} = $epoch || 0;
		$self->{ ${prefix}."by"}        = $creator;
		$self->{ ${prefix}."byUserName"}= $userName if $userName;
		$self->{ ${prefix}."byUname"}   = $uname;
		$self->{ ${prefix}."byGname"}   = $gname;
		$self->{ ${prefix}."byHostName"}= $hostname;
	    }

	} elsif (/^Owner: ([^\s]*)\s*: ([^\s\$]*)(.*)/) {
	    my $user = $1;
	    my $userPerm = $2;

	    $self->{user} = $user;
	    $self->{userPerm} = $userPerm;

	    if ($user =~ /([^\/]*)\/(.*)/) {
		$self->{userUname} = $2;
	    }

	} elsif (/^Group: ([^\s]*)\s*: ([^\s\$]*)(.*)/) {
	    my $group = $1;
	    my $groupPerm = $2;

	    $self->{group} = $group;
	    $self->{groupPerm} = $groupPerm;

	    if ($group =~ /([^\/]*)\/(.*)/) {
		$self->{groupGname} = $2;
	    }

	} elsif (/^Other: ([^\s]*)\s*: ([^\s\$]*)(.*)/) {
	    ## $self->{other} = $1;      # nothing to save here.
	    $self->{otherPerm} = $2;

	} elsif (/^Additional groups: (.*)/) {     # Note: two formats here:
	    $self->{additionalgroups} = $1;        # 1: string, and 2: array
	    $self->addList('additionalgroupsList', split(' ', $1));

	} elsif (/^Properties: (.*)/) {            # Note: three formats here:
	    $self->{properties} = $1;                 # 1: single string
	    my(@props) = split(' ', $1);
	    foreach (@props) {
		$self->{"prop_$_"} = "true";          # 2: separate strings
	    }
	    $self->addList('propertiesList', @props); # 3: array attribute

	} elsif (/^Text mode: (.*)/) {
	    $self->{textmode} = $1;

	#______________________________________________________
	# Addition to parse for output of "lsview -prop [-full]" header:
	# "  * cobb_ciatools    /ClearCase/netView/cobb/cobb_ciatools"
	# "    cobb_panck       /ClearCase/netView/cobb/cobb_panck"

	} elsif ( /^(\*|\s)\s(\S+)\s+(\S+)$/ ) {
	    my $active = $1;
	    $self->{name} = $2;
	    $self->{globalPath} = $3;
	    $self->setActive() unless $active eq " ";

	#______________________________________________________
	# Unknown input
	} else {
	    $self->addUnparsed( $_ ) if $_;
	}
    }
    $self->{count} = 1;

    return $self;
}
#_________________________
1; # Required by require()
