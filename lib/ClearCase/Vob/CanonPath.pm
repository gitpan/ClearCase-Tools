# -*- Perl -*-
#
# File:  ClearCase/Vob/CanonPath.pm
# Desc:  Reduce an "explicit path" to a "canonical path"
# Auth:  Douglas B. Robinson
# Date:  Wed Feb  5 11:48:27 2003
# Stat:  Prototype
#
# Synopsis:
#        use ClearCase::Vob::CanonPath;
#
#        $canonPath = ClearCase::Vob::CanonPath->parse( $explicitPath );
#
#   or   $cpathObj  = new ClearCase::Vob::CanonPath;
#        $canonPath = $cpathObj->parse( $explicitPath );
#
#        my($status,$error) = $cpathObj->status;
#        $status and die $error;
#
# Note:  This class handles the case where an element is nameed 'main'.
# WARN:  This class does not work when elem name contains '@@' chars
#        (which, while valid in ClearCase, is really dumb to do).

package ClearCase::Vob::CanonPath;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA $Debug );
 $VERSION = '0.06';
#@ISA     = qw( );                   # Defines interitance relationships

 $Debug   = 0;

 my($myname) = $0 =~ s:.*/::;

sub new    { bless {}, ref($_[0])||$_[0]  }   # $self is a simple hash ref.
sub set    { $_[0]->{$_[1]}=$_[2]         }   # 'param' combines 'set'/'get'
sub get    { return( length($_[0]->{$_[1]}) ? "$_[0]->{$_[1]}" : ""     ) }
sub param  { $_[2] ? $_[0]->{$_[1]}=$_[2] : return( $_[0]->{$_[1]}||""  ) }
sub setErr { return( $_[0]->{STATUS}=$_[1]||0, $_[0]->{ERROR}=$_[2]||"" ) }
sub status { return( $_[0]->{STATUS}||0, $_[0]->{ERROR}||"" )             }
sub stat   { ( wantarray ? ($_[0]->{ERROR}||"") : ($_[0]->{STATUS} ||0) ) }
sub err    { return($_[0]->{ERROR}||"")                                   }

# Attribute accessors for results of last "canonpath" (aka "parse") call

sub origpath  { return($_[0]->{origpath} ||"" ) }
sub fspath    { return($_[0]->{fspath}   ||"" ) }
sub leaf      { return($_[0]->{leaf}     ||"" ) }
sub branchver { return($_[0]->{branchver}||"" ) }
sub branch    { return($_[0]->{branch}   ||"" ) }
sub version   { return( length($_[0]->{version}) ? $_[0]->{version} : "") }

   *parse   = \&canonpath;

sub canonpath
{   my($self,$apath) = @_;
    #
    # Note: modifications to original 'canonpath' function
    # include keeping the leaf element's branch and version
    # information, if any is included in the orig "$apath".
    #
  # print "DEBUG(1): apath='$apath'\n";

    chomp($apath);
    $apath =~ s# \(([^)]*)\)$##;      # /strip/any/trailing (LABEL NAMES)

    if (ref $self) {
	$self->set('fspath',    "");
	$self->set('branchver', "");
	$self->set('branch',    "");
	$self->set('version',   "");
    } else {
    	$self = $PACK->new;      # Allow for Class or object method
    }
    $self->setErr(0,"");                  # Reset any prior error condition

    if (! $apath) {
	return(undef) unless wantarray;
	return($self,undef);
    }

    my($okpath, $extendpath) = split(/\@\@/o, $apath, 2);
    $extendpath =~ s#\@\@##g  if $extendpath;
    $extendpath =~ s#//#/#g   if $extendpath;
    my $otherpath = "";

    my($outpath,@leaves,$leaf,$branchver,$branch,$version);
    my(@branches) = ();

    $self->dpr("left=$okpath");
    if (defined($extendpath)) {
	$self->dpr("right=$extendpath");
    } else {
	$self->dpr("right=");
    }

    if ((!defined($extendpath)) || ($extendpath eq "")) {
	# got exactly what we want!
	$outpath = $okpath;

    } elsif ((!defined($otherpath)) || ($otherpath eq "")) {
	# got okpath and extendpath, now need to eliminate
	# all the bad stuff from extendpath:
	@leaves = split(m:/:o, $extendpath);
	$outpath = "";
	if (@leaves && ($leaves[0] eq "")) {
	    $self->dpr("dump(1) BLANK");
	    shift(@leaves);
	}
	while (@leaves) {
	    $self->dpr("-----------");
	    $self->dpr("leaves(A) @leaves");
	    @branches = ();

	    while (@leaves && ($leaves[0] ne 'main')) {
	 ## while (@leaves && (($leaves[0] and $leaves[0] ne 'main')
	 ## ||    ($leaves[1] and $leaves[1] eq 'main'))) {

		$self->dpr("leaves[0]=$leaves[0]");
		$self->dpr("leaves[1]=$leaves[1]") if $leaves[1];

		$outpath = $outpath . "/" . shift(@leaves);
		$self->dpr("ou1=$outpath");
	    }
	    if (@leaves) {
		$self->dpr("leaves(B) @leaves");
		$self->dpr("dump(2) " . shift(@leaves));     # dump 'main'
		push @branches, "main";
		while (@leaves && !(($leaves[0] =~ "^[0-9]+\$") || ($leaves[0] =~ "^CHECKEDOUT\.[0-9]+\$"))) {
		    $leaf = shift(@leaves);
		    push @branches, $leaf if defined($leaf);
		    $self->dpr("dump(3) $leaf")     if defined($leaf);
		}
		$leaf = shift(@leaves);           # dump or keep? see next...

		if (defined($leaf)) {
		    if ($leaf =~ "^[0-9]+\$" && $leaves[0] 
		    && $leaves[0] eq 'main') {
			#
			# Handle case where element name is 'main'
			#
			$self->dpr("dump(4) $leaf");    # dump version

			$self->dpr("leaves[0]=$leaves[0] (AND JustDumpedVers)");
			$outpath = $outpath . "/" . shift(@leaves);
			$self->dpr("ou1=$outpath");

			pop @branches;    # oops: pop prior vers from branches

		    } else {
			push @branches, $leaf;      # keep branch (may be ver)
			$self->dpr("dump(5) $leaf");
		    }

		}  # END:  if (defined($leaf)) {

	    }  # END:  if (@leaves) {
	}  # END:  while (@leaves && ($leaves[0] ne 'main')) {

	$outpath = "${okpath}/${outpath}";
	$self->dpr("ou2=$outpath");

    } else {
	$self->setErr(-1, "Warning: unexpected path fragment \"$otherpath\"\n");
	return "" unless wantarray;
	return($self, "");
    }
    while ( $outpath =~ s://:/:go ) { }
    $self->dpr("ou3=$outpath");

 ## if ($outpath =~ m#//#) { die }

    $outpath =~ s:/[.]/:/:go;
    $outpath =~ s:/$::o;
    $self->dpr("ou4=$outpath");
 ## $self->dpr("ouB=@branches");

    $branchver = ("/". join('/', @branches)) if @branches;
    $branchver ||= "";

    ($version) = $branchver =~ m#/(\d*)?$#;
    $version   = "" unless defined($version);

    $branch    = $branchver;
    $branch   =~ s#/$version$## if defined( $version );

    (my $undef, $leaf) = $outpath =~ m#(.*)/(.*)$#;
    $leaf    ||= $outpath;

    $self->dpr("ouB=BV:$branchver, B:$branch,  V:$version");

  # print "DEBUG(2): apath='$apath'\n";

    $self->set('origpath',  $apath);
    $self->set('fspath',    $outpath);
    $self->set('leaf',      $leaf);
    $self->set('branchver', $branchver);
    $self->set('branch',    $branch);
 ## $self->set('version',   "$version");   # doesn't allow for "zero"
    $self->{version} =      "$version";    # allows for version zero

    return $outpath unless wantarray;
    return($self, $outpath, $branchver, $branch, $version);
}

sub import
{   my($class,@args) = @_;
    $args[0] and $args[0] =~ /debug/i ? $Debug = 1 : 0;
    return;
}

sub dpr
{
    print STDOUT "DEBUG: @_\n" if $Debug;
}

sub perr
{
    print STDERR "${myname}: Error: @_\n";
}

sub dump {
    my($self)= @_;
    my($pack,$file,$line)=caller();
    my $text  = "DEBUG: ($PACK\:\:dump)\n  self='$self'\n";
       $text .= "CALLER $pack at line $line\n  (in file $file)\n";
    #
    # The following assumes that the current object 
    # is a simple hash ref ... modify as necessary.
    #
    foreach my $param (sort keys %$self) {
	$text .= " $param = $self->{$param}\n";
    }
    $text .= "_" x 25 ."\n";
    return($text);
}
#_________________________
1; # Required by require()

__END__

=head1 NAME

ClearCase::Vob::CanonPath - Reduce an 'explicit path' to a 'canonical path'

=head1 VERSION

This document describes version 0.06, released August, 2003.

=head1 SYNOPSIS

       use ClearCase::Vob::CanonPath;
  or   use ClearCase::Vob::CanonPath  qw( Debug );

       $canonPath = ClearCase::Vob::CanonPath->parse( $explicitPath );

  or   $cpathObj  = new ClearCase::Vob::CanonPath;
       $canonPath = $cpathObj->parse( $explicitPath );

       my($stat,$err) = $cpathObj->status;
       $stat and die $err;

=head1 DESCRIPTION

Given an 'explicit path' to an element in a ClearCase Vob
reduce it to a 'canonical path'

=head2 Constructor

=over 4

=item new 

A constructor is provided for convenience. The methods in this
module work as either class or object methods. Adding a B<Debug>
parm to the B<use> statement will result in several extra lines
of output on STDERR during path parsing.

Example:

     use ClearCase::Vob::CanonPath;
 or  use ClearCase::Vob::CanonPath  qw( Debug );

     $cpathObj = new ClearCase::Vob::CanonPath;

=back


=head2 Methods

=over 4

=item canonpath ( ExplicitPath ) 

=item parse ( ExplicitPath ) 

Reduce an 'explicit path' to a 'canonical path.' The B<canonpath>
and B<parse> methods are synonymous.

Examples:

 $explicitPath = '/vobTag/users/.@@/main/1/llf/main/12/install/main/1/README/main/2';

 $canonPath = ClearCase::Vob::CanonPath->parse( $explicitPath );

 $canonPath = $cpathObj->parse( $explicitPath );


Where B<$canonPath> will, in this example, contain the following string.

 /vobTag/users/llf/install/README

=back


=item origpath

=item fspath

=item leaf

=item branch

=item version

=item branchver

Obtain various attributes collected during a prior successful call to
the B<canonpath> method.

 $origpath  = $cpathObj->origpath;     # original "view extended" path
 $fspath    = $cpathObj->fspath;       # canonical file system path
 $leaf      = $cpathObj->leaf;         # leaf name only from fspath
 $branch    = $cpathObj->branch;       # leaf's "/branch" (if any)
 $version   = $cpathObj->version;      # leaf's version   (if any)
 $branchver = $cpathObj->branchver;    # "/branch/ver"    (if any)


=item status

=item stat

=item err

Determine whether an error occurred during the last call to a method on
this object. The B<stat> method returns different values depending on
the calling context.

 ($stat,$err) = $cpathObj->status;

 $stat = $cpathObj->stat;
 ($err)= $cpathObj->stat;

 $err = $cpathObj->err;


=head1 WARNINGS

This class B<does not> work when an element name contains '@@' chars
(which, while valid in ClearCase, is a really dumb thing to do).

Note, however, that this class B<does> successfully handle the
case where an element is named 'main'.


=head1 INHERITANCE

None currently.


=head1 AUTHOR

Douglas B. Robinson, E<lt>robinson@cup.hp.comE<gt> and
Chris Cobb, E<lt>chris@ccobb.netE<gt>.


=head1 COPYRIGHT

Copyright (c) 2003 by Hewlett-Packard. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
