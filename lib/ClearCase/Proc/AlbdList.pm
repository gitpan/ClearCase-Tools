# -*- Perl -*-
#
# File:  ClearCase/Proc/AlbdList.pm
# Desc:  Collect information on running VOB and View servers 
# Date:  Fri Oct 01 09:36:51 2004
# Stat:  Prototype, Experimental
# ToDo:  Complete parsing of various output lines.
#
# See "POD" for Synopsis, Description and other usage details.
# after the __END__ of this module.
#

package ClearCase::Proc::AlbdList;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.06';
#@ISA     = qw( );

my $albd_list = "/usr/atria/etc/utils/albd_list";

sub new    { bless {}, ref($_[0])||$_[0]  }   # $self is a simple hash ref.
sub set    { $_[0]->{$_[1]}=$_[2]         }   # Note that the 'param' method
sub get    { return( $_[0]->{$_[1]}||"" ) }   #    combines 'set' and 'get'
sub param  { $_[2] ? $_[0]->{$_[1]}=$_[2] : return( $_[0]->{$_[1]}||"" )  }
sub setErr { return( $_[0]->{STATUS}=$_[1]||0, $_[0]->{ERROR}=$_[2]||"" ) }
sub status { return( $_[0]->{STATUS}||0, $_[0]->{ERROR}||"" )             }
sub stat   { ( wantarray ? ($_[0]->{ERROR}||"") : ($_[0]->{STATUS} ||0) ) }
sub err    { return($_[0]->{ERROR}||"")   }
sub result { return $_[0]->{'result'};    }
sub count  { $_[0]->{count} ||0           }
sub list   { sort keys %{ $_[0]->{hRef} } }
sub notUp  {!$_[0]->isUp($_[1])           }
sub isa    { $_[0]->isUp($_[1]) ? $_[0]->{hRef}->{$_[1]}->{isa}           : "" }
sub pid    { $_[0]->isUp($_[1]) ? $_[0]->{hRef}->{$_[1]}->{PID}           : "" }
sub isView { $_[0]->isUp($_[1]) ? $_[0]->{hRef}->{$_[1]}->{isa} eq "View" : "" }
sub isVob  { $_[0]->isUp($_[1]) ? $_[0]->{hRef}->{$_[1]}->{isa} eq "VOB"  : "" }

# This next method is useful, when parsing a view_server log file, for
# cases where the PID is logged without a PATH, the PATH only contains
# the leaf name, or the PATH contains arbitrary extra path segments.

sub getPathForPid
{   my($self,$pid) = @_;
    return 0 unless $pid;
    my $hRef = $self->{hRef};
    foreach my $path (keys %$hRef) {
	return $path if ($pid == $hRef->{$path}->{PID});
    }
    return "";
}

sub isUpByPath
{   my($self,$path) = @_;
    return 0 unless $path;
    return( defined $self->{hRef}->{$path} ? 1 : 0 );
}

*path          = \&getPathForPid;
*isUp          = \&isUpByPath;
*isRunning     = \&isUpByPath;
*notRunning    = \&notUp;
*isaViewServer = \&isView;
*isaVobServer  = \&isVob;

#______________
# FIX: complete parsing of various output lines

# sub albdAddr      { $_[0]->{hRef}->{albd_server}->{albd_addr}      }
# sub albdPort      { $_[0]->{hRef}->{albd_server}->{albd_port}      }
# sub adminSock     { $_[0]->{hRef}->{admin_server}->{admin_tcp_sock}}
# sub adminVers     { $_[0]->{hRef}->{admin_server}->{admin_tcp_vers}}

# sub statSock      { $_[0]->{hRef}->{stat_server}->{stat_udp_sock}  }
# sub statVers      { $_[0]->{hRef}->{stat_server}->{stat_udp_vers}  }
# sub vobdbSock     { $_[0]->{hRef}->{db_server}->{db_udp_sock}      }
# sub vobdbVers     { $_[0]->{hRef}->{db_server}->{db_udp_vers}      }
# sub vobrpcSock    { $_[0]->{hRef}->{rpc_server}->{vobrpc_tcp_sock} }
# sub vobrpcVers    { $_[0]->{hRef}->{rpc_server}->{vobrpc_tcp_vers} }
#______________

sub vobUdpPath    { $_[0]->{hRef}->{$_[1]}->{vob_udp_path}  }
sub vobUdpUuid    { $_[0]->{hRef}->{$_[1]}->{vob_udp_uuid}  }
sub vobUdpSock    { $_[0]->{hRef}->{$_[1]}->{vob_udp_sock}  }
sub vobUdpVers    { $_[0]->{hRef}->{$_[1]}->{vob_udp_vers}  }

*vobPath = \&vobUdpPath;
*vobUuid = \&vobUdpUuid;
*vobSock = \&vobUdpSock;
*vobVers = \&vobUdpVers;

sub viewTcpPath   { $_[0]->{hRef}->{$_[1]}->{view_tcp_path} }
sub viewTcpUuid   { $_[0]->{hRef}->{$_[1]}->{view_tcp_uuid} }
sub viewTcpSock   { $_[0]->{hRef}->{$_[1]}->{view_tcp_sock} }
sub viewTcpVers   { $_[0]->{hRef}->{$_[1]}->{view_tcp_vers} }

*viewPath = \&viewTcpPath;
*viewUuid = \&viewTcpUuid;
*viewSock = \&viewTcpSock;
*viewVers = \&viewTcpVers;

sub viewUdpPath   { $_[0]->{hRef}->{$_[1]}->{view_udp_path} }
sub viewUdpUuid   { $_[0]->{hRef}->{$_[1]}->{view_udp_uuid} }
sub viewUdpSock   { $_[0]->{hRef}->{$_[1]}->{view_udp_sock} }
sub viewUdpVers   { $_[0]->{hRef}->{$_[1]}->{view_udp_vers} }

sub unparsed      { $_[0]->{unparsed} }

sub uuid
{   return $_[0]->viewTcpUuid( $_[1] ) if ($_[0]->isaViewServer( $_[1] ));
    return $_[0]->vobUdpUuid ( $_[1] ) if ($_[0]->isaVobServer ( $_[1] ));
    return "";
}

sub sock
{   return $_[0]->viewTcpSock( $_[1] ) if ($_[0]->isaViewServer( $_[1] ));
    return $_[0]->vobUdpSock ( $_[1] ) if ($_[0]->isaVobServer ( $_[1] ));
    return "";
}

sub run
{   my($self,$host,$path,$matchType,$matchPath,$matchPid) = @_;

    $path ||= "";
    $host ||= "";

    ref $self or $self = $PACK->new;      # Allow for Class or object method
    $self->setErr(0,"");                  # Reset any prior error condition

    $self->{hRef}  = {};
    $self->{count} = 0;
    $self->{matchingType} = 1 if $matchType;
    $self->{matchingPath} = 1 if $matchPath;

  # if (! ($path || $host)) {
  #	$self->setErr(-1,"Need 'path' and/or 'host' in 'run' method of $PACK");
  #
  # } elsif ($path and ! -d $path) {   # path may be on remote host...
  #	$self->setErr(-1,"The 'path' is not valid in 'run' method of $PACK");
  # }

    if (! $self->stat) {
	my $cmd;               # ensure correct spacing in $cmd string
	$cmd  = "$albd_list ";
	$cmd .= "-s $path "    if $path;
	$cmd .= $host          if $host;

	if ($cmd =~ /^(.*)$/) { $cmd = $1;            # untaint cmd
	} else { die "Error: invalid characters found in cmd string"; }

	##print "DEBUG: cmd='$cmd'\n";

	chomp( $self->{result} = `$cmd 2>&1` );       # run the command

	if ( $? ) {
	    $self->setErr( $?, $self->{result} );
	} else {
	    $self->parseResult($matchType,$matchPath,$matchPid);
	}
    }
    return( $self,$self->{status},$self->{error} ) if wantarray;
    return $self;
}

sub formatResult
{   my($self,$incUuid,$incSocket) = @_;

    my $text;
    my $count = $self->count;

    return unless $count;

  # if ($self->{matchingType} or $self->{matchingPath} ) {
  #	$text .= "\nFound $count running servers matching selection criteria.\n\n";
  # } else {
  #	$text .= "\nFound $count running servers.\n\n";
  # }
    my $heading;
    $heading  = "Storage Path";
    $heading .= " / UUID"           if $incUuid;
    $heading .= " / Socket number"  if $incSocket;

    $text .= sprintf("%6s  %-5s %s\n",   "PID", "Type", $heading);
    $text .= sprintf("%6s  %-5s %s\n", "-----", "----", "-"x58);

    my($pid,$isa, $detail,$uuid,$sock);

    foreach my $path ( $self->list ) {
        $pid  = $self->pid ( $path );
        $isa  = $self->isa ( $path );
        $uuid = $self->uuid( $path );
        $sock = $self->sock( $path );

        $detail  = "";
        $detail .= " $uuid   "       if $incUuid;
        $detail .= " socket: $sock"  if $incSocket;

        $text .= sprintf("%6d  %-5s %s\n", $pid, $isa, $path);
        $text .= sprintf("%13s %s\n\n","", $detail)  if $detail;
    }
    chomp( $text) if ($incUuid or $incSocket);   # remove trailing "\n"
    $text .= "-"x72 ."\n";

    return $text;
}


sub parseResult
{   my($self,$matchType,$matchPath,$matchPid) = @_;

    $matchType ||= "";
    $matchType = "" unless ($matchType =~ /^(vob|view)$/i);

    my $text = $self->result || return;

    my $done = 0;
    my($temp, $path,$skip) = ({},"",0);
    my $sect = "";
    my $skipUntilPid = 0;

    foreach (split("\n",$text)) {
	#print "DEBUG: line='$_'\n";

	#__________________________________________________________
	# Albd Server and Admin Server info

      # FIX: complete parsing of these attributes

      #	if (/^albd_server addr = ([^,]*), port= (\d+)/) {
      #	    $self->{hRef}->{albd_server}->{albd_addr} = $1;
      #	    $self->{hRef}->{albd_server}->{albd_port} = $2;

      #	} elsif (/^\s*admin_server, tcp socket (\d+): version (\d+)/) {
      #	    $temp->{hRef}->{admin_server}->{admin_tcp_sock} = $1;
      #	    $temp->{hRef}->{admin_server}->{admin_tcp_vers} = $2;

      #	} elsif (/^PID (\d+):/) {
	#__________________________________________________________

	# View and VOB Sever Info

      if (/^PID (\d+):/) {                    # ---- NEXT ----

	    # Note: the "$path" can get reset, below, if this method
	    # was passed "$matchType" and/or "$matchPath" criteria.

	    #$path and print "*****: skip='$skip' isa='$temp->{isa}' path='$path'\n";
	    if ($path and ! $skip) {                     # have prior

		if ($matchPid and ($matchPid != $temp->{PID})) {
		    # do nothing.
		} else {
		    $self->{hRef}->{$path} = $temp;      # save prior,
		    $self->{count}++;                    #  and count
		}
	    }
	    ($temp,$path,$skip) = ({},"",0);             # start new
	    $skipUntilPid = 0;
	    $temp->{PID} = $1;                           # save pid

	} elsif (/^Albd_list complete/) {     # ---- LAST ----

	    #$path and print "*****: skip='$skip' isa='$temp->{isa}' path='$path'\n";
	    if ($path and ! $skip) {                     # have prior?

		if ($matchPid and ($matchPid != $temp->{PID})) {
		    # do nothing.
		} else {
		    $self->{hRef}->{$path} = $temp;      # save final,
		    $self->{count}++;                    #  and count
		}
	    }
	    $done = 1;

	} elsif ($skipUntilPid) {

	    next;

	} elsif (/^\s*Storage path (.*)/) {

	    $temp->{ "${sect}_path" } = $1;              # save path
	    $path = $1;                                  # and use as key

	    # If we have "$matchPath" criteria, skip this entry if
	    # the "$path" string doesn't match the supplied pattern.
	    # Also, reset the "$path" so this whole set of entries
	    # is not saved, above, when we detect a new PID.
	    # AlsoAlso, wrap the match in an eval, so we don't end
	    # up with warnings if someone passes a bogus match str.
	    # For eval to work, must delay variable interpolation
	    # by escaping the leading "\$".

	    if ($matchPath) {
		unless ( eval"\$path =~ /\$matchPath/" ) {
		    #$path = "";                          # reset $path
		    $skip = 1;                           # skip this one
		}
	    }

	} elsif (/^\s*UUID (.*)/) {
	    $temp->{ "${sect}_uuid" } = $1;              # save uuid

	} elsif (/^\s*view_server, udp socket (\d+): version (\d+)/) {
	    $sect = "view_udp";
	    $temp->{view_udp_sock} = $1;
	    $temp->{view_udp_vers} = $2;
	    $temp->{isa}          = "View";

	    if ($matchType) {
		unless ($matchType =~ /view/i) {
		    #$path = "";                          # reset $path
		    $skip = 1;                           # skip this one
		    next;
		}
	    }

	} elsif (/^\s*view_server, tcp socket (\d+): version (\d+)/) {

	    # If we have "$matchType" criteria, skip this entry if
	    # the match string doesn't include "View","view",etc.
	    # Also, reset the "$path" so this whole set of entries
	    # is not saved, above, when we detect a new PID.

	    $sect = "view_tcp";
	    $temp->{view_tcp_sock} = $1;
	    $temp->{view_tcp_vers} = $2;
	    $temp->{isa}          = "View";

	    if ($matchType) {
		unless ($matchType =~ /view/i) {
		    #$path = "";                          # reset $path
		    $skip = 1;                           # skip this one
		    next;
		}
	    }

	#__________________________________________________________
	# VOB Server Info

	} elsif (/^\s*vob_server, udp socket (\d+): version (\d+)/) {

	    # If we have "$matchType" criteria, skip this entry if
	    # the match string doesn't include "VOB","Vob","vob".
	    # Also, reset the "$path" so this whole set of entries
	    # is not saved, above, when we detect a new PID.

	    if ($matchType) {
		unless ($matchType =~ /vob/i) {
		    #$path = "";                          # reset $path
		    $skip = 1;                           # skip this one
		    next;
		}
	    }

	    $sect = "vob_udp";
	    $temp->{vob_udp_sock} = $1;
	    $temp->{vob_udp_vers} = $2;
	    $temp->{isa}          = "VOB";

	    #print "DEBUG: isa='VOB' sock='$1'  vers='$2'\n";

      #-----------------------------------------------------------------
      # FIX: handle parsing multiple db_server/statistics_server pairs
      #-----------------------------------------------------------------

       	} elsif (/^\s*vobrpc_server, tcp socket (\d+): version (\d+)/) {

	    $skipUntilPid = 1;
	    next;

	    if ($matchType) {
		unless ($matchType =~ /rpc/i) {
		    #$path = "";                          # reset $path
		    $skip = 1;                           # skip this one
		    next;
		}
	    }

       	    $sect = "vobrpc_tcp";
       	    $temp->{vobrpc_tcp_sock} = $1;
       	    $temp->{vobrpc_tcp_vers} = $2;
	    $temp->{isa}             = "RPC";

       	} elsif (/^\s*db_server, tcp socket (\d+): version (\d+)/) {

	    $skipUntilPid = 1;
	    next;

	    if ($matchType) {
		unless ($matchType =~ /db/i) {
		    #$path = "";                          # reset $path
		    $skip = 1;                           # skip this one
		    next;
		}
	    }

       	    $sect = "db_tcp";
       	    $temp->{db_tcp_sock} = $1;
       	    $temp->{db_tcp_vers} = $2;
	    $temp->{isa}         = "DB";

	#__________________________________________________________
	# Statistics Server Info

       	} elsif (/^\s*statistics_server, tcp socket (\d+): version (\d+)/) {

	    $skipUntilPid = 1;
	    next;

	    if ($matchType) {
		unless ($matchType =~ /stat/i) {
		    #$path = "";                          # reset $path
		    $skip = 1;                           # skip this one
		    next;
		}
	    }

       	    $sect = "stat_tcp";
       	    $temp->{stat_tcp_sock} = $1;
       	    $temp->{stat_tcp_vers} = $2;
	    $temp->{isa}           = "Stat";

	#__________________________________________________________
	# Anything left unparsed??

	} else {
	    $self->{unparsed} .= "$_\n";
	}
    }
    return if $done;

    $self->setErr(-1,"End of list marker 'Albd_list complete' not found.");
}

sub dump {
    my($self) = @_;
    my($pack,$file,$line)=caller();
    my $text  = "DEBUG: ($PACK\:\:dump)\n  self='$self'\n";
       $text .= "CALLER $pack at line $line\n  ($file)\n";
    #
    # The following assumes that the current object 
    # is a simple hash ref ... modify as necessary.
    #
    my $value;
    foreach my $param (sort keys %$self) {
	$value = $self->{$param};
	$value = $self->zeroStr( $value, "" );  # handles value of "0"
	$text .= " $param = $value\n";
    }
    $text .= "_" x 25 ."\n";
    return($text);
}

sub zeroStr
{   my($self,$value,$undef) = @_;
    return $undef unless defined $value;
    return "0"    if (length($value) and ! $value);
    return $value;
}
#_________________________
1; # Required by require()

__END__

=head1 NAME

ClearCase::Proc::AlbdList - Collect info on VOB and View servers 

=head1 VERSION

This document describes version 0.06, released February, 2005.

=head1 DEPENDENCIES

This class depends upon the ClearCase '/usr/atria/etc/utils/albd_list' 
command.


=head1 SYNOPSIS

    use ClearCase::Proc::AlbdList;

    $AlbdList = "ClearCase::Proc::AlbdList";

    $albd = run AlbdList( undef, $storagePath );
 or $albd = run AlbdList( $host, undef        );
 or $albd = run AlbdList( $host, $storagePath, $matchType, $matchPath );

    ($stat,$err) = $albd->status;

    $count= $albd->count;                 # count of running servers
    $pid  = $albd->pid ( $storagePath );  # process id of a server
    $type = $albd->isa ( $storagePath );  # "View" or "VOB" server
    $uuid = $albd->uuid( $storagePath );  # UUID of View or VOB server
    $sock = $albd->sock( $storagePath );  # Socket of View or VOB server

    if ( $albd->isRunning( $storagePath )  ) { ... }
    if ( $albd->notRunning( $storagePath ) ) { ... }

    if ( $albd->isaVobServer( $storagePath )  ) { ... }
    if ( $albd->isaViewServer( $storagePath ) ) { ... }

    print $albd->formatResult;
    print $albd->formatResult( "incUuid", "incSocket" );

    $unparsedText = $albd->unparsed;
    print $albd->dump;


=head1 DESCRIPTION

This class is used to collect information on running VOB and View servers.


=head2 Constructor

=over 4

=item run ( [ HostName ] [, StoragePath ] [, MatchType ] [, MatchPath ] [, MatchPID ])


=over 4

=item HostName

An optional VOB or View Server B<HostName> can be provided to return
information about all VOB and/or View Server processes running on a
particular host.

=item StoragePath

An optional VOB or View local B<StoragePath> can be provided to return
information only about a particular VOB or View.

=item MatchType

An optional string that must equal either 'B<view>' or 'B<vob>' and is
used as a simple match criterion to limit the resulting output. It is
probably not a good idea to combine this with the B<StoragePath> option.

=item MatchPath

An optional string that can equal any part of the resulting server
B<StoragePath> string(s), used as a simple match criterion to limit 
the resulting output. It is probably not a good idea to combine this 
with the B<StoragePath> option.

=item MatchPid

An optional integer that can equal any one of the resulting server
B<PID> process identifier(s), used as a simple match criterion to limit 
the resulting output. It is probably not a good idea to combine this 
with the B<StoragePath> option.

=back

=back


=head2 Methods

=over 4

=item count

This method returns the number of active VOB and/or View server
processes found, based on the provided input criteria.


=item path ( ServerPid )

This method returns the local storage path of an active VOB or View server 
process corresponding to a server's B<PID> (process ID) parameter.

=item pid ( StoragePath )

This method returns the process identifier (PID) of an active VOB or View 
server process, specified by a local B<StoragePath> parameter.


=item type ( StoragePath )

This method returns the I<type> of the server process, either 'B<VOB>' or
'B<View>', as specified by a local B<StoragePath> parameter.

See the 'isaVobServer' and 'isaViewSever' methods, below.


=item uuid ( StoragePath )

Returns the UUID of the VOB or View server specified by a local
B<StoragePath> parameter.


=item sock ( StoragePath )

Returns the Socket number of the VOB or View server specified by a local
B<StoragePath> parameter.

Note that for VOB servers this is a B<UDP> port number, while
for View servers this is a B<TCP> port number.

=item isRunning ( StoragePath )

=item notRunning ( StoragePath )

These methods return a 'boolean' value indicating whether or not a server
process is running for a particular 'B<VOB>' or 'B<View>', as specified by 
a local B<StoragePath> parameter.


=item isaVobServer ( StoragePath )

=item isaViewServer ( StoragePath )

These methods return a 'boolean' value indicating whether or not a 
particular process is a 'B<VOB>' or 'B<View>' server, as specified by a 
local B<StoragePath> parameter.

See the 'type' method, above.

=item formatResult ( [ IncUuid ] [, IncSocket ] )

This method returns a text string containing formatted output generated
from a prior call to the L<run|"constructor"> method. By default it includes
the server's process ID (PID), the 'type' of the server 'View' or 'VOB',
and the file system storage path associated with each server in the list.

=over 4

=item IncUuid

An optional flag to include each server's UUIDs in the formatted output.

=item IncSocket

An optional flag to include each server's Socket number in the formatted output.

=back

Example:

   PID  Type  Storage Path
 -----  ----  ----------------------------------------------------------
  1635  View  /ClearCase/newview/baseline/i80_bl2004_1011
 11520  View  /ClearCase/newview/baseline/i80_bl2004_1012
 17441  VOB   /ClearCase/vob/lp_test/lp_test.vbs
------------------------------------------------------------------------

=item status

=item stat

=item err

 ($stat,$err) = $albd->status;

 $stat  = $albd->stat;       # status number returned in scalar context 
 ($err) = $albd->stat;       # error message returned in array context 

 ($err) = $albd->err;

=item unparsed

This method returns any output from the 'albd_list' command that
remains unrecognized by the output parser in this class.

Note that currently there will most likely be unparsed output as
the parser does not completely handle all of the possible output.


=item dump

Display contents of the current B<AlbdList> object. This may be useful
during testing and debugging, but does not produce a "pretty" format.

Example:

 print $tmplObj->dump;

=back


=head1 WARNINGS

Currently only B<VOB> and B<View> servers are reported using this module. 
Other server types, including I<admin>, I<albd>, I<db>, I<rpc>, I<stat>,
are silently omitted from the collection of parsed data.

=head1 INHERITANCE

None currently.


=head1 SEE ALSO

See L<albd_list>.


=head1 AUTHOR

Chris Cobb


=head1 COPYRIGHT

Copyright (c) 2004-2005 by Hewlett-Packard. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
