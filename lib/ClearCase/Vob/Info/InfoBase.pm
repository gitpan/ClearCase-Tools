# -*- Perl -*-
#
# File:  ClearCase/Vob/Info/InfoBase.pm
# Desc:  Base Class for ClearCase::Vob::Info::<module> classes
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#
# Note:  Abstract base class -- defines ALL methods for ALL subclasses.
#        Defining additional methods in subclasses will work, but that
#        violates standard polymorphism rules (substitution principles).
#
# WARN:  This base class is used elsewhere. Be careful when making any
#        changes! For example, this class is the base class for subclass
#        "ClearCase::Migrate::Element::ElementBase".
#
# Synopsis:
#
#  New ClearCase information (InfoBase) objects are intended to be
#  created "automatically" using the "ClearCase::Vob::Info" class.
# 
#      use "ClearCase::Vob::Info";
#      $ClearTool = "ClearCase::Vob::Info";
#  
#      $objRef = $ClearTool->run( "<ClearTool subcommand w/options>" );
#
#      $value  = $objRef->get('paramName');
#
#      $objRef->set('paramName', "New Value");
#
#
#  Determine if the current object is "checked out." (This requires
#  that the appropriate parsing subclass detect and set this attribute
#  using the "setCheckedout" method.)
#
#      $objRef->isCheckedout       # will return 1 or 0
#      $objRef->notCheckedout      # will return 1 or 0
#
#      $objRef->setCheckedout;     # flag object as "checkedout"
#      $objRef->resetCheckedout;   # flag object not "checkedout"
#
#
#  Determine the "file type" of the current object. (This requires
#  that the appropriate parsing subclass detect and set this attribute
#  using the "setFile", "setDirectory" or "setSymlink" methods.)
#  Of course, this desigination is not appropriate for all objects.
#
#      $objRef->isaFile;           # will return 1 or 0
#      $objRef->notFile;           # will return 1 or 0
#
#      $objRef->isaSymlink;        # will return 1 or 0
#      $objRef->notSymlink;        # will return 1 or 0
#
#      $objRef->isaDirectory;      # will return 1 or 0
#      $objRef->notDirectory;      # will return 1 or 0
#
#
#  Determine if the current object contains unparsed data. (This requires
#  that the appropriate parsing subclass detect and set this attribute
#  using the "addUnparsed" method.)
#
#      $objRef->unparsed;          # returns "" or the unparsed
#  or  $objRef->getUnparsed;       #   portion of the text
#
#  
#  Compare two objects that inherit from this class.
#
#      $diff = $objA cmp $objB;
#
#  or  $diff = $objA->compare($objB);
#      $diff = $objA->compare($objB,"","",@attributeList);
#
#  or  $diff = $objA->compare($objA,$objB);
#      $diff = $objA->compare($objA,$objB,"",@attributeList););
#
#
#  Generating debugging output to determine object state
#
#   print $objRef->dump;                # show contents, don't expand refs
#   print $objRef->dump("expand");      # expand all non-object refs
#   print $objRef->dump("objects");     # expand all refs to $maxDepth
#   print $objRef->dump("objects",1);   # expand all refs only to 1st level
#   print $objRef->dump("objects",9);   # expand all refs to 9th level
#
#  By default $maxDepth = 5; objects and references are only expanded down
#  to the 5th level. Beyond that the output is long and difficult to read.
#  As an alternative, select sub-objects and "dump" them separately.
#

package ClearCase::Vob::Info::InfoBase;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA $ClearToolVersion $MultiToolVersion );
 $VERSION = '0.18';
#@ISA     = qw( );          # No interitance for this base class

 use Date::Parse;           # str2time( "date string" );
#use Date::Format;          # time2str( "%c", $time   );
#use PTools::Loader;        # dynamically load "comparison" class

 $ClearToolVersion = 4.2;
 $MultiToolVersion = 4.2;


sub new
{   my($class) = @_;
    my $self = bless {}, ref($class)||$class;
    $self->{_ISA} = "";
    return $self;
}
### new    { bless {}, ref($_[0])||$_[0]  }
sub set    { $_[0]->{$_[1]}=$_[2]         }   # Note that the 'param' method
sub get    { return( $_[0]->{$_[1]}||"" ) }   #    combines 'set' and 'get'
sub param  { $_[2] ? $_[0]->{$_[1]}=$_[2] : return( $_[0]->{$_[1]}||"" )  }
sub del    { return( delete $_[0]->{$_[1]} ) if defined $_[0]->{$_[1]}    }

sub setErr { return( $_[0]->{STATUS}=$_[1]||0, $_[0]->{ERROR}=$_[2]||"" ) }
sub status { return( $_[0]->{STATUS}||0, $_[0]->{ERROR}||"" )             }
sub stat   { ( wantarray ? ($_[0]->{ERROR}||"") : ($_[0]->{STATUS} ||0) ) }
sub err    { return($_[0]->{ERROR}||"")                                   }


sub setCmd { $_[0]->{_cmd} = $_[1]   ||""   }
sub getCmd { return( $_[0]->{_cmd}   ||"" ) }

sub setMatch { $_[0]->{_match} = $_[1] ||""   }
sub getMatch { return( $_[0]->{_match} ||"" ) }

# Fetch type of the current element.
#
sub getElemType     { return( $_[0]->{_ISA} ||"" ) }

# Determine whether the current element is a file.
#
sub setBranch       { $_[0]->{_ISA} = "Branch" }
sub isaBranch       { return( $_[0]->{_ISA} eq "Branch" ? 1 : 0) }
sub notBranch       { return( $_[0]->{_ISA} eq "Branch" ? 0 : 1) }

# Determine whether the current element is a file.
#
sub setFile         { $_[0]->{_ISA} = "File" }
sub isaFile         { return( $_[0]->{_ISA} eq "File" ? 1 : 0) }
sub notFile         { return( $_[0]->{_ISA} eq "File" ? 0 : 1) }

# Determine whether the current element is a directory.
#
sub setDirectory    { $_[0]->{_ISA} = "Directory" }
sub isaDirectory
    { ( $_[0]->{_ISA} ? ($_[0]->{_ISA} eq "Directory" ? 1 : 0) : 0 ) }
sub notDirectory
    { ( $_[0]->{_ISA} ? ($_[0]->{_ISA} eq "Directory" ? 0 : 1) : 1 ) }

# Determine whether the current element is version zero.
#
sub isVerZero       { return( $_[0]->{vernum} == 0 ? 1 : 0) }
sub notVerZero      { return( $_[0]->{vernum} == 0 ? 0 : 1) }

   *isVersionZero  = \&isVerZero;
   *notVersionZero = \&notVerZero;

# Determine whether the current element is a symlink.
#
sub setSymlink      { $_[0]->{_ISA} = "Symlink" }
sub isaSymlink      { return( $_[0]->{_ISA} eq "Symlink" ? 1 : 0) }
sub notSymlink      { return( $_[0]->{_ISA} eq "Symlink" ? 0 : 1) }

# Determine whether the current element is actually View Private
#
sub setViewPrivDir  { $_[0]->{_ISA} = "ViewPrivDir" }
sub isaViewPrivDir  { return( $_[0]->{_ISA} eq "ViewPrivDir" ? 1 : 0) }
sub notViewPrivDir  { return( $_[0]->{_ISA} eq "ViewPrivDir" ? 0 : 1) }

sub setViewPrivFile { $_[0]->{_ISA} = "ViewPrivFile" }
sub isaViewPrivFile { return( $_[0]->{_ISA} eq "ViewPrivFile" ? 1 : 0) }
sub notViewPrivFile { return( $_[0]->{_ISA} eq "ViewPrivFile" ? 0 : 1) }

# Determine whether the current element is a View.
#
sub setView         { $_[0]->{_ISA} = "View" }
sub isaView         { return( $_[0]->{_ISA} eq "View" ? 1 : 0) }
sub notView         { return( $_[0]->{_ISA} eq "View" ? 0 : 1) }

# Unknown element type
#
sub setUnknown      { $_[0]->{_ISA} = "*Unknown*" }
sub isUnknown       { return( $_[0]->{_ISA} eq "*Unknown*" ? 1 : 0) }

   *typeUnknown = \&isUnknown;
   *unknownType = \&isUnknown;

# Determine whether the current View is "Active"
#
sub setActive       { $_[0]->{_active} = 1  }
sub resetActive     { $_[0]->{_active} = "" }
sub isActive        { return( $_[0]->{_active} ? 1 : 0) }
sub notActive       { return( $_[0]->{_active} ? 0 : 1) }

# Determine whether the current element is "checked out."
#
sub setCheckedout   { $_[0]->{_checkedout} = "CHECKEDOUT"   }
sub resetCheckedout { $_[0]->{_checkedout} = ""             }
sub isCheckedout    { return( $_[0]->{_checkedout} ? 1 : 0) }
sub notCheckedout   { return( $_[0]->{_checkedout} ? 0 : 1) }

# Determine whether the current element is "obsolete."
#
sub setObsolete     { $_[0]->{_locked} = "Obsolete"     }
### resetObsolete   { $_[0]->{_locked} = ""             }
   *resetObsolete = \&resetLocked;
sub isObsolete      { return( $_[0]->{_locked} eq "Obsolete" ? 1 : 0) }
sub notObsolete     { return( $_[0]->{_locked} eq "Obsolete" ? 0 : 1) }

# Determine whether the current element is "locked."
#
sub setLocked       { $_[0]->{_locked} = "Locked"         }
sub resetLocked     { $_[0]->{_locked} = ""               }
sub isLocked        { return( $_[0]->{_locked} ? 1 : 0)   }
sub notLocked       { return( $_[0]->{_locked} ? 0 : 1)   }

   *unLocked  = \&notLocked;

# Any text unrecognized by the various parsers will reside in the
# attribute "_unparsed" ... subclasses use the "addUnparsed" method.
#
sub addUnparsed { $_[0]->{_unparsed} .= "$_[1]\n"   }
sub getUnparsed { return( $_[0]->{_unparsed}||"" )  }

   *unparsed = \&getUnparsed;     # define method "aliases" for convenience

   *setAttr = \&set;
   *getAttr = \&get;

   *setError= \&setErr;
   *toStr   = \&dump;

   *setList = \&set;
   *setHash = \&set;

# Notes:
#  The syntax for "aaddList" and "addHash" provide methods to
#  help make this class a general-purpose "data container."
#
#  The syntax for "getList" and "getHash" simply allows for a
#  default "attribute" name of "list" or "hash" for the method.
#  When called in 'scalar' context a reference is returned, but
#  when called in 'array' context the array is returned.

sub addList
{   my($self,$param,@values) = @_; 
    return unless @values;
    $param ||= 'list';
    defined $self->{$param} or $self->{$param} = [];   # "initialize"
    return unless ref($self->{$param}) and ref($self->{$param}) eq "ARRAY";

    #my $count = $#values + 1;
    #print "DEBUG: adding $count '$param' values: @values\n";

    return push @{ $self->{$param} }, @values;
}

sub getList
{   my($self,$param) = @_; 
    $param ||= 'list';
    return unless (ref($self->{$param}) and ref($self->{$param}) eq "ARRAY");
    return $self->{$param} unless wantarray;
    return @{ $self->{$param} };
}

sub delList
{   my($self,$param) = @_; 
    return( delete $self->{$param} ) if ref($self->{$param}) eq "ARRAY";
    return( [] );
}

   *putHash = \&addHash;

sub addHash
{   my($self,$param,$key,$value) = @_; 
    return unless $key;
    $param ||= 'hash';
    defined $self->{$param}{$key} or $self->{$param}{$key} = {};   # "init"
    return unless ref($self->{$param}) and ref($self->{$param}) eq "HASH";
    return $self->{$param}{$key} = $value;
}

sub getHash
{   my($self,$param,$key) = @_; 
    $param ||= 'hash';
    return unless (ref($self->{$param}) and ref($self->{$param}) eq "HASH");
    if ($key) {
	return $self->{$param}{$key} unless wantarray;
	return %{ $self->{$param}{$key} };
    } else {
	return $self->{$param} unless wantarray;
	return %{ $self->{$param} };
    }
}

sub delHash
{   my($self,$param) = @_; 
    return( delete $self->{$param} ) if ref($self->{$param}) eq "HASH";
    return( {} );
}

sub count
{   my($self,$attrName) = @_;

    $attrName ||= "list";
    return -1 unless defined $self->{$attrName};

    return( $#{ $self->{$attrName} } );
}

# The following 'iterator' routines allow for easily working
# through any "ARRAY reference" attribute stored in objects
# of this class. See usage in the synopsis for this class.

sub reiterate
{   my($self,$attrName) = @_;
    return $self->addHash('_iterator', ($attrName || "list"), 0);
}

sub iterate
{   my($self,$attrName) = @_;

    $attrName ||= "list";
    my $idx = $self->getHash('_iterator', $attrName) || 0;

    return undef unless ref($self->{$attrName});
    return undef if     $idx > $#{ $self->{$attrName} };

    $self->addHash('_iterator', $attrName, ($idx + 1));

    return( ${ $self->getList($attrName) }[$idx] ||"" );
}

# Often, in objects based on this class, a "list" of values is used to
# keep track of multiple sub-objects stored in a "container" object.
# Using the "iterate" method, above, returns the next "name" in a list.
# Usually, in these cases, what we usually want is the next sub-object 
# itself and not just its name. 
#
# To further complecate things, the programmer sometimes will know that
# there should only be ONE ITEM in the list, and s/he just wants the item
# (object or whatever) that is named by that one name.
#
# This situation resulted in some rather obnoxious syntax, especially
# when we didn't really want the container object at all. E.g.:
#
#    $infoObj = $parserObj->run( 'some cleartool command' );
#
#    $infoObj = $infoObj->get( $infoObj->getList );    # Yuck!
#
# This next method was added to alleviate such poor syntax. It's quite
# similar to the "iterate" method, above. However, this method returns
# the object (or whatever) that is NAMED by the item in the "list" that
# we are iterating.
#
#    $infoObj = $parserObj->run( 'some cleartool command' );
#
#    $infoObj = $infoObj->getIterate;           # A little better!
#
# Sound confusing? It will become second nature after using this once
# or twice. Just remember not to use both "iterate" and "getIterate"
# in the same loop (because that WILL get rather confusing, as both
# methods will increment the index for the list being "iterated"
# [unless, of course, you are iterating different "list names"]).
#
# OBTW, if there is no "list name" argument supplied to the methods
# (as in these examples), the default name is "list" (which HAPPENS
# to be the default name used when creating lists of things in
# objects based on this class). Any "list name" value can be used.
#
# Also, if you can think of a better method name (that makes good sense,
# both syntactically and semantically, in most situations) that would
# make things even better still. Feel free to add another method alias!
#
#  *theThingWeReallyWantedInTheFirstPlace = \&getIterate;

   *getNextInList = \&getIterate;

sub getIterate
{   my($self,$attrName) = @_;

    # Get the next NAME in the LIST attribute
    #
    my $nextInList = $self->iterate($attrName);

    return undef unless defined $nextInList;

    # Return the VALUE for that NAME, if any
    #
    $self->get($nextInList);
}

sub getFirstInList                         # Even better still ...
{   my($self,$attrName) = @_;

    $self->reiterate( $attrName );
    $self->getIterate( $attrName );
}

# Due to the screwy way in which 'cleartool' and 'multitool' generate
# their output, it is nice to know if anything remains "unparsed."
# The following methods will provide this information.

#sub setAbortIfUnparsed   { }
#sub resetAbortIfUnparsed { }

sub warnIfUnparsed { return $_[0]->abortIfUnparsed("warnOnly") }

sub abortIfUnparsed
{   my($self,$warnOnly,$errPrefix,$warnPrefix) = @_;

    my $unparsed = $self->getUnparsed || return 0;

    my $text = ($warnOnly ? $warnPrefix || "Warning" : $errPrefix || "Error");

    my($pack,$file,$line)=caller();

    print "\n$text: ClearTool Parser object contains 'unparsed' output.\n";
    print "\nUnparsed data:";
    print "\n$unparsed\n";

    my $cmdString = $self->getCmd;
    print "\nTextFrom: $cmdString" if $cmdString;

    print "\nLocation: line $line in class $pack\n($file)\n\n";

    return 1 if $warnOnly;

    die $self->dump('expand');
}

sub datestrToEpoch
{   my($self,$datestr) = @_;
    #
    # Translate those strangly formatted ClearCase date strings
    # into an "epoch" number to allow for easy date manipulation.
    #
    my $epoch = 0;

    if ($datestr =~ /^(\d{4})(\d\d)(\d\d)\.(\d\d)(\d\d)(\d\d)$/) {

	$epoch = str2time("$1/$2/$3 $4:$5:$6");  # E.g.:  20030403.110605

    } elsif ($datestr =~ /^(\d\d-\w\w\w-\d\d\d?\d?)\.(\d\d:\d\d:\d\d)$/) {

	$epoch = str2time("$1 $2");              # E.g.:  03-Apr-03.11:06:05
    }
    return( $epoch );
}

sub DESTROY { }
#{   my($self) = @_;
#    print "DEBUG: Destroy $self\n";
#    return;
#}

# Overloading the "cmp" operator along with the following
# routines make it possible to compare any two objects (that
# based on this class) for equivalence.
# FIX: move all of the following subroutines to another class
#      (perhaps ::Info::InfoBaseCompare) and dynamically load
#      them when first needed. These probably won't be used much.

 use overload
	 "cmp" => sub { $PACK->compare( @_ ) },
    "fallback" => 1;


sub compare 
{   my($class,$obj1,$obj2,$rev,@attrs) = @_;

    # Note: When invoked via "compare" as an object method, we
    #       need to swap some of the arguments around. This is 
    #       not done when invoked as a class method via the 
    #       overloaded "cmp" operator.
    #
    if (ref $class && $obj1 && ! $obj2) {
	($obj1, $obj2) = ($class, $obj1);
    }
    my($incompatible,$equivalent,$different) = (-1,0,1);

    return $incompatible unless UNIVERSAL::isa($obj1,$PACK);
    return $incompatible unless UNIVERSAL::isa($obj2,$PACK);
    #
    # If we get this far $rev will never be true 

#print "COMPARE ENTRIES: obj1='$obj1' \n\t\t obj2='$obj2\n";

    (@attrs) = () unless @attrs;
    my($subCompare) = 0;

#my(@DEBUGKEYS) = sort keys %$obj1;
#print "COMPARE ON KEYS='@DEBUGKEYS'\n";

    foreach my $key (sort keys %$obj1) {

	# If we have a list of attribute names, only compare
	# those attributes we find in the list.
	#
#print "COMPARE ATTR key='$key' IF IN list='@attrs'\n";

	@attrs and next unless grep(/^$key$/, @attrs);

	##return $incompatible unless $key;
	##return $different unless exists $obj1->{$key};
	return $different unless exists $obj2->{$key};

#print "COMPARE ATTR key='$key'\n";

	# Warn: Add "length" tests to compare "" and "0" correctly.
	#
	if ( ref( $obj1->{$key} ) ) {

#print "INVOKE 'SubCompare' for ATTR '$key'\n";
	    $subCompare = 
		$class->compareRef($obj1->{$key},$obj2->{$key},@attrs);
	    return $subCompare unless $subCompare == 0;

	} else {

	    my $attr1 = $obj1->{$key};
	    my $attr2 = $obj2->{$key};

	    if ( (($attr1 eq $attr1) or ($attr1 == $attr2))
             and  ( length($attr1)   ==  length($attr2)  )  ) {

#print "COMPARE ATTR EQUIV key1='$obj1->{$key}'  key2='$obj2->{$key}'\n";
		next;
	    } else {
#print "COMPARE ATTR DIFFER key1='$obj1->{$key}'  key2='$obj2->{$key}'\n";
	        return $different;
	    }

	    return $different unless ($obj1->{$key} eq $obj2->{$key})
		and ( length($obj1->{$key}) == length($obj2->{$key}) );
	}
    }
    return $equivalent;
}

sub compareRef
{   my($class,$ref1,$ref2,@attrs) = @_;

    my($incompatible,$equivalent,$different) = (-1,0,1);
    my($ary1,$ary2,@ary1,@ary2) = ();
    my($val1,$val2,$key1,$key2) = ();

# print "SUBCOMPARE ENTRY: ref1='$ref1'  ref2='$ref2'\n";

    (@attrs) = () unless scalar @attrs;
    my($subCompare) = 0;

    if (ref($ref1) eq "ARRAY"       and ref($ref2) eq "ARRAY") {

	# First, compare array element counts
	return $different unless $#{ $ref1 } == $#{ $ref2 };

	# Second, compare array element contents
	(@ary1) = ( @{$ref1} );
	(@ary2) = ( @{$ref2} );

	foreach my $idx (0 .. $#ary1) {

    	    ($val1,$val2) = ( $ary1[$idx] ||"", $ary2[$idx] ||"" );

#   print "SUBCOMPARE ARY[$idx] val1='$val1'  val2='$val2'\n";

	    if ( ref($val1) ) {
	        # WARN: this does NOT avoid infinite recursion:
		#
	        $subCompare = $class->compareRef($val1,$val2,@attrs);
	        return $subCompare unless $subCompare == 0;

	    } else {
		return $different unless ( $val1 eq $val2 )
		    and ( length($val1) == length($val2) );
	    }
	}

    } elsif (ref($ref1) eq "HASH"   and ref($ref2) eq "HASH") {
	# First, compare array element counts
	$key1 = join(',', sort keys %$ref1);
	$key2 = join(',', sort keys %$ref2);
	return $different unless $key1 eq $key2;

	foreach my $key (sort keys %$ref1) {

	    @attrs and next unless grep(/^$key$/, @attrs);

    	    ($val1,$val2) = ( $ref1->{$key}, $ref2->{$key} );

#   print "SUBCOMPARE ATR{$key} val1='$val1'  val2='$val2'\n";

	    if ( ref($val1) ) {
	        # WARN: this does NOT avoid infinite recursion:
		#
	        $subCompare = $class->compareRef($val1,$val2,@attrs);
	        return $subCompare unless $subCompare == 0;

	    } else {
		return $different unless ( $val1 eq $val2 )
		    and ( length($val1) == length($val2) );
	    }
	}

    } elsif (ref($ref1) eq "CODE"   and ref($ref2) eq "CODE") {
	return 0;

    } elsif (ref($ref1) eq "SCALAR" and ref($ref2) eq "SCALAR") {
	return $different unless ( $$ref1 eq $$ref2 )
	    and ( length($$ref1) == length($$ref2) );

    } elsif ($ref1->can("compare")  and $ref2->can("compare")) {
        # WARN: this does NOT avoid infinite recursion:
	#
# print "RE-COMPARE ENTRY: ref1='$ref1'  ref2='$ref2'\n";
	return $ref1->compare($ref1,$ref2,undef,@attrs);

    } else {
    	return $incompatible;
    }

    return $equivalent;
}

my $defaultMaxDepth = 5;

sub dump
{   my($self,$expandRefs,$maxDepth,$curDepth) = @_;
    $expandRefs ||= "";
    $maxDepth   ||= $defaultMaxDepth;
    $curDepth   ||= 0;

    my $notExpandedNote = "--No expansion: max depth of $maxDepth exceeded--\n";
    my $text = "";

    $text .= "-" x 25 ."\n";
    $text .= "DEBUG: ($PACK\:\:dump)\n  self='$self'\n";

    if ($curDepth == 0) {
	my($pack,$file,$line)=caller();
	$text .= "CALLER $pack at line $line\n($file)\n";
    } elsif ($curDepth > $maxDepth) {
	$text .= $notExpandedNote;
	return $text;
    }

    foreach my $param (sort keys %$self) {
	next unless defined $self->{$param};
	$text .= " $param = $self->{$param}\n";

	# Optional reference expansion
	#
	if ( ref($self->{$param}) and $expandRefs ) { 
	    my $val = $self->{$param};

	    ref($val) and $text .= 
		$self->expandRef($val,$expandRefs,$maxDepth,$curDepth +1);
	}
    }
    $text .= "-" x 25 ."\n";

    return($text);
}


sub expandRef
{   my($self,$ref,$expandRefs,$maxDepth,$curDepth) = @_;
    $expandRefs ||= "";
    $maxDepth   ||= $defaultMaxDepth;
    $curDepth   ||= 0;

    #
    # NOTE the funky recursion here ... sometimes we call this
    # subroutine from below and sometimes we call "dump" which
    # may well end up right back here again. When making mods,
    # be sure to retain "$maxDepth" and "$curDepth" correctly.
    #

    my $notExpandedNote = "--No expansion: max depth of $maxDepth exceeded--\n";
    my $val     = "";
    my $subText = "";

    # prevent infinite recursion ...
    return $notExpandedNote if $curDepth > $maxDepth;

    if (ref($ref) eq "ARRAY") {
	foreach ( 0..$#{ $ref } ) { 
	    $subText .= "  [$_] ${$ref}[$_]\n"; 
	    $val   = ${$ref}[$_]; 
	    ref($val) and 
		$subText .= 
		    $self->expandRef($val,$expandRefs,$maxDepth,$curDepth +1);
	}

    } elsif (ref($ref) eq "HASH") {
	foreach (sort keys %$ref) {
	    $subText .= "  {$_} => $ref->{$_}\n"; 
	    $val   = $ref->{$_}; 
	    ref($val) and 
		$subText .= 
		    $self->expandRef($val,$expandRefs,$maxDepth,$curDepth +1);
	}

    } elsif (ref($ref) eq "CODE") {
	$subText .= "--No expansion: code reference ignored--\n";

    } elsif (ref($ref) eq "SCALAR") {
	$subText .= "  = $$ref\n";     # Dreference the scalar

    # Optional sub-object expansion. Don't just ass*u*me that
    # it's an object that inherits from this base class ...
    #
    } elsif ($expandRefs eq "objects" and $ref->can("dump")) {

 	if ($ref->isa($PACK)) {        # USE CUR DEPTH HERE:
 	    $subText .= $ref->dump($expandRefs,$maxDepth,$curDepth );  ## +1);
 	} else {
 	    $subText .= $ref->dump;    # WARN: this could add a lot of text.
 	}
    }

    if ($subText) {
	return( "\n--EXPAND: Depth $curDepth -- $ref --\n"
	      . $subText 
	      . "--RETURN: Depth $curDepth -- $ref --\n\n" );

    } else {
	return "";
    }
}
#_________________________
1; # Required by require()

__END__

=head1 NAME

ClearCase::Vob::Info::InfoBase - Base class for ClearCase::Vob::Info::E<lt>moduleE<gt> classes

=head1 VERSION

This document describes version 0.18, released October, 2005.

=head1 DEPENDENCIES

Dependencies for this class include the following.

  1)  Rational's ClearCase "cleartool" command interpreter.

=head1 SYNOPSIS

       use "ClearCase::Vob::Info";
       $ClearTool = "ClearCase::Vob::Info";

       $objRef = $ClearTool->run( "<ClearTool subcommand w/options>" );

       $value  = $objRef->get('paramName');

       $objRef->set('paramName', "New Value");

=head1 DESCRIPTION

This is an abstract base class that defines ALL methods for ALL subclasses.
Defining additional methods in subclasses will work, but that
violates standard polymorphism rules (substitution principles).

As shown in the B<SYNOPSIS> section, above, objects of this class are
not intended to be instantiated directly. This class provides the
B<interface inheritance> necessary to keep all subclasses polymorphic.

B<WARN>: This base class is used elsewhere. Be careful when making any
changes. For example, this class is also the base for subclass
B<ClearCase::Migrate::Element::ElementBase>.

B<NOTE>: The B<run> method in the B<ClearCase::Vob::Info> class will
create a new and separate cleartool process for each and every command
that is run. To create a persistent cleartool or multitool process see
the B<ClearCase::Proc::ClearTool> class.

=head2 Constructor

=over 4

=item new

Create a reference to a new object of this class. This class is not
intended to be instantiated directly. This class is used by designers
of various subclasses that parse the output of cleartool and multitool 
sub-commands. 

See the B<SYNOPSIS> section, above, for intended usage. See the
B<Public Methods> section, below, for an overview of the intended
interface.

=back

=head2 Public Methods

=over 4

=item get ( Attribute )

=item getAttr ( Attribute )

Obtain the value for a given attribute. Each object that is a subclass
of this class will contain attributes with widely varying names. 

Use the B<dump> method, described below, as a quick and easy way to determine 
what attributes are available in a given object based on this class. This is
useful when developing modules that access parsed cleartool/multitool output.

=item getCmd

=item getMatch

=item getElemType

Obtain information, when available, about

  The cleartool/multitool command used to generate the current output,

  The match criteria used to collect a subset of the current output,

  The type of the ClearCase element for which the current object is a
  representation.

=item isaBranch

=item notBranch

Determine the I<element type> of the current object. 

B<Note> that this assumes the appropriate parsing subclass has detected
and set this attribute using the "setBranch", "setFile", "setDirectory"
or "setSymlink" method as appropriate for the current object.

       $objRef->isaBanch;          # will return 1 or 0
       $objRef->notBanch;          # will return 1 or 0

=item isaFile

=item notFile

Determine the I<element type> of the current object.
See additional notes under the B<isaBranch>/B<notBranch> methods, above.

       $objRef->isaFile;           # will return 1 or 0
       $objRef->notFile;           # will return 1 or 0

=item isaDirectory

=item notDirectory

Determine the I<element type> of the current object.
See additional notes under the B<isaBranch>/B<notBranch> methods, above.

       $objRef->isaDirectory;      # will return 1 or 0
       $objRef->notDirectory;      # will return 1 or 0

=item isaSymlink

=item notSymlink

Determine the I<element type> of the current object.
See additional notes under the B<isaBranch>/B<notBranch> methods, above.

       $objRef->isaSymlink;        # will return 1 or 0
       $objRef->notSymlink;        # will return 1 or 0

=item isaView

=item notView

Determine the I<element type> of the current object.

       $objRef->isaView;           # will return 1 or 0
       $objRef->notView;           # will return 1 or 0

=item isUnknown

=item typeUnknown

=item unknownType

If no I<element type> was set for the current object, then the
type is I<unknown>.
See additional notes under the B<isaBranch>/B<notBranch> methods, above.

       $objRef->isUnknown;         # will return 1 or 0
       $objRef->typeUnknown;       # will return 1 or 0

=item isActive

=item notActive

Determine if the current View is "active." (This requires
that the appropriate parsing subclass detect and set this attribute
using the protected B<setActive> method.)

       $objRef->isActive;          # will return 1 or 0
       $objRef->notActive;         # will return 1 or 0

=item isCheckedout

=item notCheckedout

Determine if the current object is "checked out." (This requires
that the appropriate parsing subclass detect and set this attribute
using the protected B<setCheckedout> method.)

       $objRef->isCheckedout;      # will return 1 or 0
       $objRef->notCheckedout;     # will return 1 or 0

=item isObsolete

=item notObsolete

Determine if the current object is "locked obsolete." (This requires
that the appropriate parsing subclass detect and set this attribute
using the protected B<setObsolete> method.)

       $objRef->isObsolete;        # will return 1 or 0
       $objRef->notObsolete;       # will return 1 or 0

=item isLocked

=item unLocked 

=item notLocked

Determine if the current object is "locked." (This requires
that the appropriate parsing subclass detect and set this attribute
using the protected B<setLocked> method.)

       $objRef->isLocked;          # will return 1 or 0
       $objRef->notLocked;         # will return 1 or 0

=item getList ( [ ListAttribute ] )

=item getHash ( [ HashAttribute [, KeyValue ] ] )

Return a reference to (in scalar mode) or a list of (in list mode) 
values stored in a I<List> or I<Hash> attribute in the current object.

By default the B<ListAttribute> name is 'B<list>', and 
the B<HashAttribute> name is 'B<hash>'. For B<HashAttrobutes> if a
B<KeyValue> is passed, only that particular value (or null) is returned.

=item count ( [ ListAttribute ] )

Return a zero-based count of the items found in the specified
B<ListAttribute>. By default the B<ListAttribute> name is 'B<list>'.

=item reiterate ( [ ListAttribute ] )

Rewind the iterator associated with a B<list> attribute. When no attribute
name is passed as a parameter, the default iterator named B<list> is 
reset to zero.

 $objRef->reiterate;                # rewind iterator for 'list' attribute
 $objRef->reiterate( 'dirList' );   # rewind iterator for 'dirList' attribute

=item iterate ( [ ListAttribute ] )

Iterate through each entry in an attribute list. If no I<iterator>
exists for the given B<ListAttribute>, a new iterator is created and 
initialized to zero upon first access.

Example: Iterate through each subdirectory in a directory object.
This example assumes that 1) a B<dirList> attribute exists in the B<$dirObj>
object and 2) that this attribute is a reference to a list (array) of
subdirectory names.

 while (my $dirEnt = $dirObj->iterate('dirList')) {

     print "  directory entry = '$dirEnt'\n";
 }


Example: Iterate through each B<element type> entry found in B<$vobTag>
via a cleartool command. This example makes use of the default I<list>
iterator that, conveniently, just happens to be created by this class
when creating the B<$elemObj> shown here.

 use ClearCase::Vob::Info;

 $ClearTool = "ClearCase::Vob::Info";     

 $elemObj = $ClearTool->run( "lstype -local -l -kind eltype -invob $vobTag" );

 while( my $elemName = $elemObj->iterate ) {

        $elemInfoObj = $elemObj->get( $elemName );

        next unless $elemInfoObj->unparsed;

        print "Oops: unparsed data in item $elemName\n";

        $errorCount++;
 }
 print "$errorCount parsing errors\n";

B<Background for this example>:
The B<$elemObj> contains a collection of objects that each contain 
specific informational details pertaining to each I<eltype> (element type)
defined in the VOB indicated by B<$vobTag>. 

Information for each element type is packaged up as one or more I<sub-objects>
during creation of the B<$elemObj>. These are stored in this I<outter> object
each in a simple named attribute.

Since multiple objects may exist, the name of each I<sub-object> is collected
in the default B<list> attribute. This provides for convenient access via
the B<iterator> method.

Iterating through the I<list> attribute simply returns the I<name> of
each I<sub-object> that is then retrieved from the I<outter> object.
Then the B<get> method is used to fetch each B<$elemInfoObj> stored in 
the B<$elemObj>.

Working with multiple objects and sub-objects gets a bit confusing at 
first. An easy way to see the internal workings of the various objects 
during development is by using the B<dump> method, explained below.


=item getIterate ( [ ListAttribute ] )

=item getNextInList ( [ ListAttribute ] )

As noted above, a 'list' of values is often used to
keep track of multiple sub-objects stored in a 'container' object.
Using the B<iterate> method, above, returns the next 'name' in a list.
Usually, in these cases, what we really want is the next sub-object 
itself and not just its name. 

To further complicate things, the programmer sometimes will know that
there should only be I<one item> in the list, and s/he just wants the
item (object or whatever) that is I<named> by that single value.

This situation resulted in some rather obnoxious syntax, especially
since, in these cases, the container object is simply discarded. 
E.g.:

 $elemObj = $ClearTool->run( "desc -l \"$elemName\"" );

 $elemObj = $elemObj->get( $elemObj->getList );    # Yuck!

This method, B<getIterate> (a.k.a. B<getNextInList>), along with the next
one, below, were added to alleviate such poor syntax. It's quite similar 
to the B<iterate> method, above. However, this method returns the I<object>
(or whatever) that is I<named> by the item in the 'list' we are iterating.

 $elemObj = $ClearTool->run( "desc -l \"$elemName\"" );

 $elemObj = $elemObj->getIterate;           # A little better!


=item getFirstInList ( [ ListAttribute ] )

This method combines both the B<reiterate> and B<getIterate> methods
to return the object (or whatever) that is named by the first item
in an 'iterator list.'

 $elemObj = $ClearTool->run( "desc -l \"$elemName\"" );

 $elemObj = $elemObj->getFirstInList        # Even better!

This, when used as shown here or combined with the method alias 
B<getNextInList>, shown above, provides for improved semantics in 
code that uses this class.

Note that immediately after a call to the B<reiterate> method for
a given list attribute, both this method and the B<getNextInList>
method will return the value for the first item defined in that list.
In other words, this method is only necessary when semantics dictate.


=item status

=item stat

=item err

Return the status and error text, when status is non-zero, of last
operation.

 ($stat,$err) = $objRef->status;

 $stat  = $objRef->stat;           # scalar context returns status number
 ($err) = $objRef->stat;           # array context returns error message

 ($err) = $objRef->err;

=item getUnparsed

=item unparsed

Determine if the current object contains unparsed data. (This requires
that the appropriate parsing subclass detect and set this attribute
using the 'addUnparsed' method.)

       $objRef->unparsed;          # returns "" or the unparsed
   or  $objRef->getUnparsed;       #   portion of the text

=item warnIfUnparsed

=item abortIfUnparsed

Generate a warning or abort message. Terminate after abort message.

=item dump

=item toStr

Generating debugging output to determine object state.

    print $objRef->dump;                # show contents, don't expand refs
    print $objRef->dump("expand");      # expand all non-object refs
    print $objRef->dump("objects");     # expand all refs to $maxDepth
    print $objRef->dump("objects",1);   # expand all refs only to 1st level
    print $objRef->dump("objects",9);   # expand all refs to 9th level

By default $maxDepth = 5; objects and references are only expanded down
to the 5th level. Beyond that the output is long and difficult to read.
As an alternative, select sub-objects and "dump" them separately.

=item compare

Compare two objects that inherit from this class.

       $diff = $objA cmp $objB;

   or  $diff = $objA->compare($objB);
       $diff = $objA->compare($objB,"","",@attributeList);

   or  $diff = $objA->compare($objA,$objB);
       $diff = $objA->compare($objA,$objB,"",@attributeList););

=back

=head2 Private Methods

=over 4

=item addList ( Attribute, Value[s] )

=item addHash ( Attribute, Key, Value )

=item addUnparsed ( Text )

These methods are used by various subclasses to add entries to
collections of data during the parsing of cleartool/multitool output.

=item set ( Attribute, Value )

=item setAttr ( Attribute, Value )

=item setList ( ListAttribute, Value )

=item setHash ( HashAttribute, Value )

These methods are used by various subclasses to initialize
attributes during the parsing of cleartool/multitool output.

=item del ( Attribute )

=item delList ( ListAttribute )

=item delHash ( HashAttribute )

These methods are available to delete various attributes from 
the current object. 

The B<del> method will delete any attribute
that is set while the B<delList> and B<delHash> methods will only 
delete the attribute if it is currently contains a reference of
the corresponding type (list reference or hash reference).

Each of these will methods return the current contents of 
the named attribute, if any. In addition, if no attribute is 
currently defined for the given I<attribute name> 
the B<delList> method will return an empty list reference and 
the B<delHash> method will return an empty hash reference.

=item setErr ( Status, TextString )

=item setError ( Status, TextString )

This method is used to indicate that an internal error state was
detected during parsing.

=item setCmd

When the cleartool/multitool command that was used to generate
the current output is known, it is saved in the B<_cmd> attribute.

=item setMatch ( MatchCriteria )

When match criteria was used to limit the output generated by the
cleartool/multitool command, it is saved in the B<_match> attribute.

Match criteria is usually only used in combination with the B<-s>
option to a given cleartool/multitool subcommand.

=item setBranch

=item setFile

=item setDirectory

=item setSymlink

=item setView

=item setUnknown

The various parsing subclasses detect and set the B<_ISA> attribute. The
value of this attribute can then be tested using public methods described
above.

=item setActive

=item resetActive

The various parsing subclasses detect and set the B<_active> attribute.

=item setCheckedout

=item resetCheckedout

The various parsing subclasses detect and set the B<_checkedout> attribute.
During normal processing invoking objects can call the B<resetCheckedout>
method if/when the state is known to have changed.

 $objRef->setCheckedout;     # flag object as "checkedout"
 $objRef->resetCheckedout;   # flag object not "checkedout"

=item setObsolete

=item resetObsolete

The various parsing subclasses detect and set the B<_locked> attribute
to the value of "Obsolete".
During normal processing invoking objects can call the B<resetObsolete>
method if/when the state is known to have changed.

 $objRef->setObsolete;     # flag object as "obsolete"
 $objRef->resetObsolete;   # flag object not "obsolete"

=item setLocked

=item resetLocked

The various parsing subclasses detect and set the B<_locked> attribute
to the value of "Locked".
During normal processing invoking objects can call the B<resetLocked>
method if/when the state is known to have changed.

 $objRef->setLocked;     # flag object as "locked"
 $objRef->resetLocked;   # flag object not "locked"

=item compareRef

=item expandRef

Internal methods used when comparing two objects that inherit from
this class.

=back


=head1 INHERITANCE

Many concrete subclasses inherit from this class. These
classes are not intended to be created directly, but via 
the B<ClearCase::Vob::Info> class.

=head1 SEE ALSO

See L<ClearCase::Vob::Info> and B<ClearCase::Proc::ClearTool>.

=head1 AUTHOR

Chris Cobb, E<lt>chris@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 2002-2003 by Hewlett-Packard. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

