# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/SymlinkType.pm
# Desc:  Information about a VOB element
# Auth:  Chris Cobb
# Date:  Mon Dec  3 10:39:21 2001
# Stat:  Prototype
#
# Synopsis:
#        use ClearCase::Vob::Info::SymlinkType;
#
#        $objRef = new ClearCase::Vob::Info::SymlinkType( @text );
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
# When the "@text" buffer contains output from the "ct dump" command,
# this will return an "ClearCase::Vob::Info::SymlinkType" object.
#

package ClearCase::Vob::Info::SymlinkType;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.01';
 @ISA     = qw( ClearCase::Vob::Info::InfoBase );

 use ClearCase::Vob::Info::InfoBase;  # include base class
 use Date::Parse;                     # str2time( "date string" );
 use Date::Format;                    # time2str( "%c", $time   );


# WARN:  Defining additional methods here should be done with care!!
#        Any methods here not available to ALL classes that have an
#        inheritance relationship to "ClearCase::Vob::Info::InfoBase"
#        violates some basic OO design tenets.

sub new
{   my($class,@text) = @_;

    bless my $self = {}, ref($class)||$class;
    $self->setErr(0,"");

    # Here we parse the output from "ct dump [-l] "
    # This class is intended to be instantiated via the
    # "ClearCase::Vob::Info" class
    #
    # Handle both an array of text strings
    # and a single multi-line text string
    #
    $#text == 0 and (@text) = split("\n", $text[0]);

    my($fstatPrefix) = ("");
    my($dirEnt,$doList,$verList,$htList,$hfList) = ("",0,0,0,0,0);

    foreach (@text) {
	##print "DEBUG: $_\n";

    ## ToDo: Eliminate unnecessary tests here ...
    ##       This class was just copied from the "Dump" class
    ##

	if (/^$/) {
	    next;

	} elsif (/^directory entries:/) {
	    ($dirEnt, $doList, $verList, $htList, $hfList) = (1,0,0,0,0);
	    $self->setDirectory;   # set "isaDirectory" flag

	} elsif (/^derived objects:/) {
	    ($dirEnt, $doList, $verList, $htList, $hfList) = (0,1,0,0,0);

	} elsif (/^versions:/) {
	    ($dirEnt, $doList, $verList, $htList, $hfList) = (0,0,1,0,0);

	} elsif (/^hyperlinks to object:/) {
	    ($dirEnt, $doList, $verList, $htList, $hfList) = (0,0,0,1,0);

	} elsif (/^hyperlinks from object:/) {
	    ($dirEnt, $doList, $verList, $htList, $hfList) = (0,0,0,0,1);

#	} elsif ($dirEnt and /^\s*(\d*)\s*(.*)/) {
#	    defined $self->{dirList} or $self->{dirList} = [];
#	    push @{ $self->{dirList} }, $2;

    ##	} elsif ($doList and /^\s*$/) {    # FIX pattern here
            # FIX: handle derived object list here

    	} elsif ($htList and /^\s*?(.*)$/) {    # FIX pattern here
            # FIX: handle hyperlinks TO OBJECT list here
	    $self->{hyperlinksToObject} .= $_;

    	} elsif ($hfList and /^\s*?(.*)$/) {    # FIX pattern here
            # FIX: handle hyperlinks FROM OBJECT list here
	    $self->{hyperlinksFromObject} .= $_;

	} elsif ($verList and /^\s*(\d*):\s*(\d*)/) {
	    defined $self->{verList} or $self->{verList} = {};
	    $self->{verList}->{$1} = $2;

	} elsif (/^oid=([^\s]*)\s*dbid=(\d*) \(([^)]*)\)/) {
	    $self->{oid}   = $1;
	    $self->{dbid}  = $2;
	    $self->{dbidx} = $3;

	# Warn: This test must occur BEFORE the "objectName/objectId" test!
	#
	} elsif (/^view="([^"]*)" \(([^)]*)\)/) {
	    $self->{viewName} = $1;
	    $self->{viewId}   = $2;

	# Warn: This test must occur AFTER the "viewName/viewId" test!
	#
	} elsif (/^(.*) \(([^)]*)\)/) {
	    $self->{objectName} = $1;
	    $self->{objectId}   = $2;

	} elsif (/elem=(\d*)  branch=(\d*)  pred ver=(\d*)  pred ver num=(\d*)  reserved=(.*)/) {
	    $self->{checkoutElemId}     = $1;
	    $self->{checkoutBranchId}   = $2;
	    $self->{checkoutPredVer}    = $3;
	    $self->{checkoutPredVerNum} = $4;
	    $self->{checkoutReserved}   = $5;

	    # FIX: confirm above test is the best way to determine 
	    # if element is currently in a "checkedout" state
	    # (other attribute values have "CHECKEDOUT" as a substring).
	    # Does this work for ALL element types during a "ct dump"??
	    #
	    $self->setCheckedout;    # see base class for this method

	} elsif (/\@\@/) {
	    chomp($self->{objectVer} = $_);

	} elsif (/^mtype=(.*)/) {
	    $self->{mtype} = $1;

	} elsif (/^stored fstat:/) {
	    $fstatPrefix = "stored";

	} elsif (/^returned fstat:/) {
	    $fstatPrefix = "returned";

	} elsif (/^ino: (.*); type: (.*); mode: (.*)/) {
	    $self->{ "${fstatPrefix}Ino"  } = $1;
	    $self->{ "${fstatPrefix}Type" } = $2;
	    $self->{ "${fstatPrefix}Mode" } = $3;

	} elsif (/^nlink: (.*); size: (.*)/) {
	    $self->{ "${fstatPrefix}Nlink" } = $1;
	    $self->{ "${fstatPrefix}Size"  } = $2;

	} elsif (/^(usid|gsid): (.*)/) {
	    my $field = $1;
	    my $value = $2;

	    $self->{ "${fstatPrefix}" . ucfirst $field } = $value;

	    if ($field eq "usid") {
		my $uid = "";
		$value  = "nobody" if $value eq "NOBODY";

		if ($value =~ /^UNIX:UID-(\d*)/) {
		    $uid = $1;
		} else {
		    my(@pwent) = getpwnam($value);
		    $uid = $pwent[2];
		}
		$self->{ "${fstatPrefix}"."Uid" } = $uid;

	    } elsif ($field eq "gsid") {
		my $gid = "";
		$value  = "nogroup" if $value eq "NOBODY";

		if ($value =~ /^UNIX:GID-(\d*)/) {
		    $gid = $1;
		} else {
		    my(@grent) = getgrnam($value);
		    $gid = $grent[2];
		}
		$self->{ "${fstatPrefix}"."Gid" } = $gid;

	    }

	} elsif (/^(atime|mtime|ctime): (\w\w\w) (\w\w\w)\s*(\d*) (\d\d:\d\d:\d\d) (\d\d\d\d)/) {
	    my $field = $1;
	    my $day   = $2;
	    my $mon   = $3;
	    my $mday  = $4;
	    my $time  = $5;
	    my $year  = $6;
	    my($epoch)= str2time("$day, $mon $mday, $year $time") || 0;

	    #print "epoch='$epoch'\n";
	    #die "$day, $mon $mday, $year $time\n";

	    my $attr  = $fstatPrefix . ucfirst $field;
	    my $stamp = "_". $attr . "Stamp";

	    $self->{$attr}  = $epoch ? time2str( "%c", $epoch ) : "0";
	    $self->{$stamp} = $epoch || 0;

	# FIX: Handle multiple comment lines (see ElementType.pm)
	} elsif (/^  "([^"]*)"/) {
	    $self->{comment} = $1;

	} elsif (/^master replica dbid=(.*)/) {
	    $self->{masterReplicaDbid} = $1;

	} elsif (/^idstr="([^"]*)"/) {
	    $self->{idstr} = $1;

	} elsif (/^elem=(\d*)\s*branch=(\d*)\s*ver num=(\d*)/) {
	    $self->{elem}   = $1;
	    $self->{branch} = $2;
	    $self->{vernum} = $3;

	} elsif (/^labels: (.*)/) {

	    # FIX: Confirm this works with multiple lables for an elem
	    #
	    my(@labels) = split(", ", $1);
	    $self->addList('labels', @labels);

	#______________________________________________________
	# Non-Directory elements
	#
	} elsif (/^cont dbid=(\d*)\s*container="([^"]*)"/) {
	    $self->{contDbid}  = $1;
	    $self->{container} = $2;

	} elsif (/^source cont="([^"]*)"/) {
	    $self->{sourceCont} = $1;

	} elsif (/^clrtxt cont="([^"]*)"/) {
	    $self->{clrtxtCont} = $1;


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
