# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/ElementType.pm
# Desc:  Information about a ClearCase element
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#
# WARN: This module may fail to correctly set the resulting 
#       object's "_ISA" attribute when the element type is a 
#       user-defined subtype.
#
# Synopsis:
#        use ClearCase::Vob::Info::ElementType;
#
#        $objRef = new ClearCase::Vob::Info::ElementType( @text );
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
# this will return an "ClearCase::Vob::Info::ElementType" object.
#

package ClearCase::Vob::Info::ElementType;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.10';
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
    $self->setUnknown;         # should be reset, below

    # Here we parse the output from "ct lstype -l ..."
    # This class is intended to be instantiated via the
    # "ClearCase::Vob::Info" class
    #
    # Handle both an array of text strings
    # and a single multi-line text string
    #
    $#text == 0 and (@text) = split("\n", $text[0]);

    my($inComment, $inLabels, $inHyperlinks, $inAttrs) = (0,0,0,0);

    foreach (@text) {
	#print "DEBUG: '$_'\n";

	if (/^(file |directory )element "([^"]*)"( from )?([^\s]*)?/) {
	    $self->{name} = $2;
	    $self->{checkedoutFrom} = $4  if $4;

	    # see base class for this method
	    #
	    $self->setCheckedout  if $2 =~ /CHECKEDOUT/;

	} elsif (/^(directory )?version "([^"]*)"( from )?([^\s]*)?/) {
	    $self->{name} = $2;
	    $self->{checkedoutFrom} = $4  if $4;

	    # see base class for this method
	    #
	    $self->setCheckedout  if $2 =~ /CHECKEDOUT/;

	} elsif (/^View private (directory|file) "([^"]*)"/) {
	    #
	    # View private thingy ... see "Modified: <date>" parser, below
	    # (the standard parser works fine for "Protection:" section)
	    #
	    my $type      = $1;
	    $self->{name} = $2;

	    $type eq "directory" and $self->setViewPrivDir;
	    $type eq "file"      and $self->setViewPrivFile;

	} elsif (/^  Labels:/) {
            ($inComment, $inLabels, $inHyperlinks, $inAttrs) = (0,1,0,0);

	} elsif (/^  Hyperlinks:/) {
            ($inComment, $inLabels, $inHyperlinks, $inAttrs) = (0,0,1,0);

	} elsif (/^  Attributes:/) {
            ($inComment, $inLabels, $inHyperlinks, $inAttrs) = (0,0,0,1);

	} elsif ($inLabels) {
	    
	    # FIX: confirm this works with multiple lables on an elem
	    #
	    my($label) = $_ =~ /^\s*(.*)/;
	    $self->addList('labels', $label);

	} elsif ($inHyperlinks) {
	    
	    # FIX: confirm this works with multiple hlinks on an elem
	    #      Also, fix the data structure as in "ElementVtree"
	    #
	    my($linkId,$direction,$target) = /^\s*([^\s]*) (<-|->) (.*)/;

	    $self->addList('hyperlinks', $linkId);

	    #if ($direction eq "<-") {
	    #	$self->addHash('linkfrom', $linkId, $target);
	    #} elsif ($direction eq "->") {
	    #	$self->addHash('linkto', $linkId, $target);
	    #} else {
	    #	$self->addUnparsed( $_ );
	    #}

	} elsif ($inAttrs and /\s*(.*)/) {
	    $self->addList('attributes', $1);

	} elsif (/^  checked out ([^\s]*) by (.*)/) {
	    #my $checkedoutDate = $1;
	    $self->{checkedoutBy} = $2;

	    my($day,$mon,$year,$time) = $1 =~
		/^(\d\d)-(\w\w\w)-(\d\d?\d?)\.(\d\d:\d\d:\d\d)/;

	    my($epoch) = str2time("$day/$mon/$year $time") || 0;

	    $self->{checkedoutDate} 
		= $epoch ? time2str( "%c", $epoch ) : "Unknown";
	    $self->{_checkedoutStamp} = $epoch || 0;

	} elsif (/^  by view: ([^\s]*) \("([^"]*)"\)/) {
	    $self->{checkedoutView} = $1;
	    $self->{checkedoutViewPath} = $2;

	} elsif (/^  Protection:/) {
	    next;

	} elsif (/^  Element Protection:/) {
	    # Whew ... parsing comments like this sucks!
	    # What's a good way to handle this mess?!

# "New snapshot from fancy. Last comment in changelog is dated 5/12/00 but lists
# "No changes." Previous changelog entry with possible changes (by allanp)
# is dated 4/19/00 (which is also the date of stacey's last changes)."

	    # If there is a comment, strip the trailing '"' char.
	    # but only do this ONCE.
	    if ($inComment and $self->{comment}) { $self->{comment} =~ s#"$##; }
	    $inComment = 0;
	    next;

	} elsif (/^  element type: (.*)/) {
	    my $elementType = $1;
	    $self->{elementType} = $elementType;
	    $self->setDirectory if $elementType =~ /^directory/;
	    $self->setFile      if $elementType =~ 
		/(file|ms_word|html|xml|rose)/;

	    # WARN: this module may fail to correctly set the 
	    #       resulting object's "_ISA" attribute when
	    #       the element is a user-defined elem type.

	    # Note: this module is not currently used to collect 
	    #       descriptions of 'symlink' elements

	    # Whew ... parsing comments like this (still) sucks!
	    # If there is a comment, strip the trailing '"' char.
	    # but only do this ONCE.
	    if ($inComment and $self->{comment}) { $self->{comment} =~ s#"$##; }
	    $inComment = 0;

	} elsif ($inComment) {
	    my($comment) = $_ =~ /^   (.*)$/;
	    $comment ||= "";
	    $self->{comment} .= "\n$comment";

	} elsif (/^  "(.*)/) {
	    $self->{comment} = $1;
	    # If no trailing '"' character, keep collecting comment lines ;-(
	    # SO, how to handle the case where the first line of a
	    # multi-line comment just happens to end in a '"' character???

	    # Only strip the trailing '"' char if it's a ONE-LINER here.
	    # NOT: We are NOT able to determine a ONE-LINER comment here!!
	    #$inComment = ($_ =~ /"$/ ? 0 : 1);
	    #if ($self->{comment} and ! $inComment) {
	    #    $self->{comment} =~ s#"$##;
	    #}

	     $inComment = 1;

        #    "ct xxxx"
	} elsif (/^ (\d\d)-(\w\w\w)-(\d\d?\d?)\.(\d\d:\d\d:\d\d) by (.*)/) {
	    my $day = $1;
	    my $mon = $2;
	    my $year = $3;
	    my $time = $4;
	    my $creator = $5;

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

        #    "ct yyyy"
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

	} elsif (/^  Modified: ([^\s]*) (\d\d\/\d\d\/\d\d) (\d\d:\d\d:\d\d)/) {
	    #
	    # "View private directory"  modification date format
	    #
	    my $day  = $1;
	    my $date = $2;
	    my $time = $3;

	    my($epoch) = str2time("$day $date $time") || 0;

	    $self->{createDate} = $epoch ? time2str( "%c", $epoch ) : "Unknown";
	    $self->{_createStamp} = $epoch || 0;

	} elsif (/^  Added file element "([^"]*)"/) {
	    $self->addList('fileElement', $1);

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

	} elsif (/^  predecessor version: (.*)/) {
	    $self->{predecessorVersion} = $1;

	} elsif (/^\s*source pool: ([^\s]*)\s*cleartext pool: ([^\s]*)(\s*derived pool: (.*))?/) {
	    $self->{sourcepool}    = $1;
	    $self->{cleartextpool} = $2;
	    $self->{derivedpool}   = $4;

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
	#______________________________________________________
	# Unknown input
	} else {
	    $self->addUnparsed( $_ );
	}
    }
    $self->{count} = 1;

    # Note: this module is not currently used to collect 
    #       descriptions of 'symlink' elements

    if ( $self->isaDirectory ) {
	$self->{_unixPerms} = "d";
    } else {
	$self->{_unixPerms} = "-";
    }
    $self->{_unixPerms} .= 
	$self->{userPerm} . $self->{groupPerm} . $self->{otherPerm};

    return $self;
}
#_________________________
1; # Required by require()
