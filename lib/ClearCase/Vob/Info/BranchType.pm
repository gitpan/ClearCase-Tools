# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/BranchType.pm
# Desc:  Information about a VOB trigger
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#
# ToDo:  Finish adding support for Attributes, Hyperlinks and Labels
#
# Synopsis:
#        use ClearCase::Vob::Info::BranchType;
#
#        $objRef = new ClearCase::Vob::Info::BranchType( @text );
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
#    "ct describe -l brtype:xx"
#    "ct lstype -l -kind brtype -invob vobtag"
# this will return an "ClearCase::Vob::Info::BranchType" object.
#

package ClearCase::Vob::Info::BranchType;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.07';
 @ISA     = qw( ClearCase::Vob::Info::InfoBase );

 use ClearCase::Vob::Info::InfoBase;
 use Date::Parse;                    # str2time( "date string" );
 use Date::Format;                   # time2str( "%c", $time   );


# WARN:  Defining additional methods here should be done with care!!
#        Any methods here not available to ALL classes that have an
#        inheritance relationship to "ClearCase::Vob::Info::InfoBase"
#        violates some basic OO design tenets.

sub new
{   my($class,@text) = @_;

    bless my $self = {}, ref($class)||$class;
    $self->setErr(0,"");
    $self->setBranch;

    # Here we parse the output from "ct lstype -l ..."
    # This class is intended to be instantiated via the
    # "ClearCase::Vob::Info" class
    #
    # Handle both an array of text strings
    # and a single multi-line text string
    #
    $#text == 0 and (@text) = split("\n", $text[0]);

    my($inComment, $inLabels, $inAttributes, $inHyperlinks) = (0,0,0,0);

    foreach (@text) {
	#print "DEBUG: $_\n";

	if (/^  Element Protection:/) {
	    next;

	} elsif (/^  Labels:/) {
            ($inComment, $inLabels, $inAttributes, $inHyperlinks) = (0,1,0,0);

    	} elsif (/^  Attributes:/) {
            ($inComment, $inLabels, $inAttributes, $inHyperlinks) = (0,0,1,0);

	} elsif (/^  Hyperlinks:/) {
            ($inComment, $inLabels, $inAttributes, $inHyperlinks) = (0,0,0,1);

    	} elsif ($inLabels and /\s*(.*)/) {

	    # FIX: confirm this works with multiple lables on an elem
	    $self->addList('labels', $1);

    	} elsif ($inAttributes and /\s*(.*)/) {
	    
	    # FIX: confirm this works with multiple attrs on an elem
	    $self->addList('attributes', $1);

	} elsif ($inHyperlinks and /\s*(.*)/) {
	    
	    # FIX: confirm this works with multiple hlinks on an elem
	    $self->addList('hyperlinks', $1);

	} elsif (/^  branch type: (.*)/) {
	    $self->{name} = $1;
	    $self->{nameLC} = lc $1;

	    # Whew ... parsing comments like this sucks!
	    # If there is a comment, strip the trailing '"' char.
	    # but only do this ONCE.
	    if ($inComment and $self->{comment}) { $self->{comment} =~ s#"$##; }
	    $inComment = 0;

	} elsif (/^branch (type )?"([^"]*)"\s?(.*)/) {
	    $self->{branch} = $2;

	   #print "branch = $2\n";
	   #print "obsol = $3\n";
	    $self->setObsolete if $3 =~ /obsolete/;

        #    "ct lstype -kind brtype"
	} elsif (/^ (\d\d)-(\w\w\w)-(\d\d?\d?)\.(\d\d:\d\d:\d\d) by (.*)/) {
	    my $day = $1;
	    my $mon = $2;
	    my $year = $3;
	    my $time = $4;
	    my $creator= $5;
	    my($epoch) = str2time("$day/$mon/$year $time") || 0;

	    $self->{createDate} = $epoch ? time2str( "%c", $epoch ) : "Unknown";
	    $self->{_createStamp} = $epoch || 0;
	    $self->{createdby}= $creator;

	    my($userName,$uname,$gname,$hostname) = 
		$creator =~ /^([^\(]*)\(([^.]*)\.([^@]*)\@([^\)]*)\)/;
	    $userName =~ s/\s*$//;

	    $self->{createdbyUserName}= $userName;
	    $self->{createdbyUname}   = $uname;
	    $self->{createdbyGname}   = $gname;
	    $self->{createdbyHostName}= $hostname;

        #    "ct describe -l brtype:xx"
	} elsif (/^  created (\d\d)-(\w\w\w)-(\d\d?\d?)\.(\d\d:\d\d:\d\d) by (.*)/) {
	    my $day = $1;
	    my $mon = $2;
	    my $year = $3;
	    my $time = $4;
	    my $creator = $5;
	    my($epoch) = str2time("$day/$mon/$year $time") || 0;

	    $self->{createDate} = $epoch ? time2str( "%c", $epoch ) : "Unknown";
	    $self->{_createStamp} = $epoch || 0;
	    $self->{createdby}= $creator;

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
	    $self->{createdbyUserName}= $userName if $userName;
	    $self->{createdbyUname}   = $uname;
	    $self->{createdbyGname}   = $gname;
	    $self->{createdbyHostName}= $hostname;

	} elsif (/^  master replica: (.*)/) {
	    my $masterReplica      = $1;
	    $self->{masterReplica} = $masterReplica;

	    if ( $masterReplica =~ /\s*([^@]*)@(.*)$/) {
		$self->{masterReplicaVob}    = $1;
		$self->{masterReplicaVobTag} = $2;
	    }

	    # Whew ... parsing comments like this sucks!
	    # If there is a comment, strip the trailing '"' char.
	    # but only do this ONCE.
	    if ($inComment and $self->{comment}) { $self->{comment} =~ s#"$##; }
	    $inComment = 0;

	} elsif (/^  request for mastership: (.*)/) {
	    $self->{requestMaster} = $1;

	} elsif (/^  owner: (.*)/) {
	    $self->{owner} = $1;

	    # Whew ... parsing comments like this sucks!
	    # If there is a comment, strip the trailing '"' char.
	    # but only do this ONCE.
	    if ($inComment and $self->{comment}) { $self->{comment} =~ s#"$##; }
	    $inComment = 0;

	} elsif (/^  group: (.*)/) {
	    $self->{group} = $1;

	} elsif (/^  scope: (.*)/) {
	    $self->{scope} = $1;

	} elsif (/^  constraint: (.*)/) {
	    $self->{constraint} = $1;

	} elsif (/^ creator = (.*)/) {
	    my $creator = $1;
	    my ($uname,$gname,$hostname)=$creator =~ /^([^.]*)\.([^@]*)\@(.*)/;
	    $self->{createdbyUname}   = $uname;
	    $self->{createdbyGname}   = $gname;
	    $self->{createdbyHostName}= $hostname;

	} elsif (/^    User : ([^\s]*)\s*: (.*)/) {
	    my $user = $1;
	    my $userPerm = $2;

	    $self->{user} = $user;
	    $self->{userPerm} = $userPerm;

	    if ($user =~ /^UNIX:UID-(\d*)/) {
		$self->{userid} = $1;
	    } else {
		$self->{userid} = $user;
	    }

	} elsif (/^    Group: ([^\s]*)\s*: (.*)/) {
	    my $group = $1;
	    my $groupPerm = $2;

	    $self->{group} = $group;
	    $self->{groupPerm} = $groupPerm;

	    if ($group =~ /^UNIX:UID-(\d*)/) {
		$self->{groupid} = $1;
	    } else {
		$self->{groupid} = $group;
	    }

	} elsif (/^    Other: ([^\s]*)\s*: (.*)/) {
	    ## $self->{other} = $1;      # nothing to save here.
	    $self->{otherPerm} = $2;

	} elsif (/^  element type: (.*)/) {
	    $self->{elementType} = $1;

	} elsif (/^  branched from version: (.*)/) {
	   #$self->{branchedFromVersion} = $1;
	    $self->{predecessorVersion} = $1;


	### FIX: Handle multiple comment lines (see ElementType.pm)
	##} elsif (/^  "([^"]*)"/) {
	##    $self->{comment} = $1;

	} elsif ($inComment) {
	    my($comment) = $_ =~ /^   (.*)$/;
	    if (! $comment) {
		# Attempt to catch parsing errors ... this test
		# will be true if text "found" here w/o a successful
		# parse test elsewhere in this module.
		($comment) = $_ =~ /^  (.*)$/;   # OOPS: parsing err!
	    }
	    $comment ||= "";
	    $self->{comment} .= "\n$comment";

	} elsif (/^  "(.*)/) {
	    $inComment and $self->{comment} .= $1;
	    $inComment  or $self->{comment} = $1;

	    # Only strip the trailing '"' char if it's a ONE-LINER here.
	    # NOT: We are NOT able to determine a ONE-LINER comment here!!
	    #$inComment = ($_ =~ /"$/ ? 0 : 1);
	    #if ($self->{comment} and ! $inComment) {
	    #    $self->{comment} =~ s#"$##;
	    #}

	     $inComment = 1;

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
