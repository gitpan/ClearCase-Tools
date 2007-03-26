# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/Dump.pm
# Desc:  Information about a VOB element
# Auth:  Chris Cobb
# Date:  Mon Dec  3 10:39:21 2001
# Stat:  Prototype
#
# Synopsis:
#        use ClearCase::Vob::Info::Dump;
#
#        $objRef = new ClearCase::Vob::Info::Dump( @text );
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
# this will return an "ClearCase::Vob::Info::Dump" object.
#

package ClearCase::Vob::Info::Dump;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.03';
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

    my($fstatPrefix,$priorVersion) = ("","");
    my($dirEnt,$doList,$verList,$htList,$hfList,$brList,$atrList,$lbList)
	  = (0,0,0,0,0,0,0,0);

    foreach (@text) {
	#print "DEBUG: $_\n";

	if (/^$/) {
	    next;

	} elsif (/^directory entries:/) {
	    ($dirEnt,$doList,$verList,$htList,$hfList,$brList,$atrList,$lbList)
		=(1,0,0,0,0,0,0,0);
	    $self->setDirectory;   # set "isaDirectory" flag

	} elsif (/^derived objects:/) {
	    ($dirEnt,$doList,$verList,$htList,$hfList,$brList,$atrList,$lbList)
		=(0,1,0,0,0,0,0,0);

	} elsif (/^versions:/) {
	    ($dirEnt,$doList,$verList,$htList,$hfList,$brList,$atrList,$lbList)
		=(0,0,1,0,0,0,0,0);

	} elsif (/^hyperlinks to object:/) {
	    ($dirEnt,$doList,$verList,$htList,$hfList,$brList,$atrList,$lbList)
		=(0,0,0,1,0,0,0,0);

	} elsif (/^hyperlinks from object:/) {
	    ($dirEnt,$doList,$verList,$htList,$hfList,$brList,$atrList,$lbList)
		=(0,0,0,0,1,0,0,0);

	} elsif (/^branches:/) {
	    ($dirEnt,$doList,$verList,$htList,$hfList,$brList,$atrList,$lbList)
		=(0,0,0,0,0,1,0,0);

	} elsif (/^attributes:/) {
	    ($dirEnt,$doList,$verList,$htList,$hfList,$brList,$atrList,$lbList)
		=(0,0,0,0,0,0,1,0);

	} elsif (/^labels: (.*)/) {
	    ($dirEnt,$doList,$verList,$htList,$hfList,$brList,$atrList,$lbList)
		=(0,0,0,0,0,0,0,1);

	    # Note this is a Two-Step process as labels may appear on 
	    # the first line with the "^labels:" tag (match here)
	    # _AND_ they may also continue as multi-line labels with
	    # no leading tag (match below).
	    #
	    my $labels = $1;
	    my(@labels)= ();
	    if ($labels =~ /,/) {                         # Confirm patterns.
		(@labels) = split(/,\s?/, $labels);
	    } else {
		(@labels) = split(" ", $labels);
	    }
	    $self->addList('labels', @labels);

	} elsif ($dirEnt and /^\s*(\d*)\s*(.*)/) {
	    defined $self->{dirList} or $self->{dirList} = [];
	    push @{ $self->{dirList} }, $2;

    ##	} elsif ($doList and /^\s*$/) {                   # FIX pattern here
            # FIX: handle derived object list here

    	} elsif ($htList and /^\s*(.*)$/) {               # Pattern OK here?
            # FIX: handle hyperlinks TO OBJECT list here
	    $self->{hyperlinksToObject} .= $_;

 	} elsif ($hfList and /^\s*(.*)$/) {               # Pattern OK here?
	    # FIX: handle hyperlinks FROM OBJECT list here
	    $self->{hyperlinksFromObject} .= $_;

	} elsif ($verList and /^\s*(\d*):\s*(\d*)/) {
	    defined $self->{verList} or $self->{verList} = {};
	    $self->{verList}->{$1} = $2;
	    $priorVersion = $1;
	} elsif ($verList and /^\s*(\d*)/) {
	    defined $self->{verList} or $self->{verList} = {};
	    length($priorVersion) or $priorVersion = "Oops:UnknownVersion";
	    $priorVersion ||= "0";
	    $self->{verList}->{$priorVersion} .= ", $1";

	} elsif ($brList and /^\s*(\d*)\s*(.*)/) {
	    $self->addList('branches', $2);

    	} elsif ($atrList and /^\s*(.*)$/) {              # Pattern OK here?
	    $self->addList('attributes', $1);

    	} elsif ($lbList and /^\s*(.*)$/) {

	    # Note this is a Two-Step process as labels may appear on 
	    # the first line with the "^labels:" tag (match above)
	    # _AND_ they may also continue as multi-line labels with
	    # no leading tag (match here).
	    #
	    my $labels = $1;
	    my(@labels)= ();
	    if ($labels =~ /,/) {                         # Confirm patterns.
		(@labels) = split(/,\s?/, $labels);
	    } else {
		(@labels) = split(" ", $labels);
	    }
	    $self->addList('labels', @labels);

	} elsif (/^oid=([^\s]*)\s*dbid=(\d*) \(([^)]*)\)/) {
	    $self->{oid}   = $1;
	    $self->{dbid}  = $2;
	    $self->{dbidx} = $3;

	# Warn: The following tests MUST occur BEFORE the test
	# for "objectName/objectId" attributes!
	#
	} elsif (/^master replica dbid=(.*)/) {
	    $self->{masterReplicaDbid} = $1;

	} elsif (/^master replica dbid \(defaulted\)=(.*)/) {
	    $self->{masterReplicaDbidDefaulted} = $1;

	} elsif (/^view="([^"]*)" \(([^)]*)\)/) {
	    $self->{viewName} = $1;
	    $self->{viewId}   = $2;

	# Warn: This test must occur AFTER the "viewName/viewId" test!
	# FIX:  Figure out a way to make this a "safer" test here.
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
	    my $mtype     = $1;
	    $mtype =~ s/\s*$//;     # This line can have trailing spaces ;-(
	    my $mtypetype = "";
	    if ( $mtype =~ /(.*)  type=(.*)$/) {
		($mtype,$mtypetype) = ($1,$2);
	    }
	    $self->{mtype}     = $mtype;
	    $self->{mtypetype} = $mtypetype if $mtypetype;

	    if ($mtype =~ /^(file|version)/) {
		$self->setFile;
	    } elsif ($mtype =~ /^symbolic/) {
		$self->setSymlink;
	    } elsif ($mtype =~ /^directory/) {
		$self->setDirectory;
	    } elsif ($mtype =~ /^branch/) {
		$self->setBranch;
	    }

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
	       $value =~ s#UNIX:(UID|GID)-##;

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

	} elsif (/^text="([^"]*)"/) {       # NOTE: for "mtype=symbolic link"
	    $self->{text} = $1;
	    $self->{_target} = $1;

	} elsif (/^idstr="([^"]*)"/) {
	    $self->{idstr} = $1;

	} elsif (/^elem=(\d*)\s*branch=(\d*)\s*ver num=(\d*)/) {
	    $self->{elem}   = $1;
	    $self->{branch} = $2;
	    $self->{vernum} = $3;

	} elsif (/^elem=([^\s]*)  pname="([^"]*)"  next ver num=(\d*)/) {
	    $self->{elem}   = $1;
	    $self->{pname} = $2;
	    $self->{nextvernum} = $3;

	} elsif (/^flags: (.*)/) {
	    $self->{flags} = $1;

	} elsif (/^source pool=([^\s]*)\s*cleartext pool=([^\s]*)(\s*derived pool=(.*))?/) {
	    $self->{sourcepool}    = $1;
	    $self->{cleartextpool} = $2;
	    $self->{derivedpool}   = $4;
	#______________________________________________________
	# Symlink elements
	#
	} elsif (/^\/(.*)/) {
	    $self->{_source} = "/$1";

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
