# -*- Perl -*-
#
# File:  ClearCase/Report/VxfsSyslog.pm
# Desc:  Parse "vxfs:" notification messages in ths system log file
# Auth:  Chris Cobb, Hewlett-Packard, Cupertino, CA  <cobb@cup.hp.com>
# Date:  Fri Aug 17 16:01:51 PDT 2001
# Stat:  Prototype
#
# ToDo:  Add additional parsing: currently only handles "vx_nospace"
#
# Synopsis:
#        use ClearCase::Report::VxfsSyslog
#
#        my $reptObj = new ClearCase::Report::VxfsSyslog;
#
#
#   Collect any "vxfs" notifications from the system log file.
#
#        $reptObj->collectData;
#
#   or   ($stat,$err)     = $reptObj->collectData;
#
#   or   $reptObj         = ClearCase::Report::VxfsSyslog->collectData;
#
#   or   ($reptObj,$stat) = ClearCase::Report::VxfsSyslog->collectData;
#
#
#   Specify alternate start time and/or alternate system log file name
#   where "$starttime" is a Unix "epoch" number that, when used, will
#   omit reporting any error(s) found prior to this time.
#
#        $reptObj->collectData( $starttime );
#
#   or   $reptObj->collectData( $starttime, $syslogfile );
#
#
#   Report any "vxfs" notifications from the system log file using 
#   the default output format.
#
#        $arrayRef = $reptObj->formatData;
#        print @{ $arrayRef };
#
#   or   print @{ $reptObj->formatData };
#
#   or   if ($reptObj->hasErrorsToReport) {
#            print @{ $reptObj->formatData };
#        } else {
#            $reportHost = $reptObj->reportHost;
#            print "$base: No errors to report on $reportHost.\n";
#        }
#
#   Report any "vxfs" notifications from the system log file as
#   "raw data" then reformat using the default report format.
#
#        $arrayRef = $reptObj->formatData( "raw" );
#
#        foreach $entry ( @$arrayRef ) {
#            print $reptObj->formatEntry( $entry );
#        }
#
#   Expand a single "raw data" entry collected from the log file.
#   This is useful when creating a new report format, and uses the
#   same "$entry" variable as shown in the example just above.
#
#        ($firsttime,$lasttime,$hostname,$devicefile,
#           $error,$path,$mesg) = $reptObj->expandEntry( $entry );
#
#   Report any "vxfs" notifications from the system log file as
#   "raw data" and write the results, if any, to another log file.
#
#        if ($reptObj->hasErrorsToReport) {
#            print LOG @{ $reptObj->formatData( "raw" ) };
#        }
#
#   Note that the raw data contains all of the parameters necessary
#   to format the "individual entry" reports, even when a combined
#   log file is used to collect errors from multiple view servers.
#   See description of the "formatEntry" and "expandEntry" methods.
#
#   Return the first/last time stamp parsed from current syslog.
#   Note that "$endtime" works well as the "$starttime" parameter
#   to the "collectData" method for subsequent runs of a script.
#   These are log file times, NOT the start/end times of the script,
#   and can be used to control subsequent runs of the script. See
#   description of the "collectData" method, above.
#
#        $startTime = $reptObj->startTime;
#        $endTime   = $reptObj->endTime;
#

package ClearCase::Report::VxfsSyslog;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.15';
#@ISA     = qw( );

 use PTools::Local;                         # Local/Global environment
 use Date::Format;                          # $dateStr = time2str("%c", time);
 use Date::Parse;                           # $epochNum= str2time("10/20/02");
 use PTools::Proc::Backtick;                # Run subprocess using `backticks`
 use PTools::SDF::File::Mnttab;             # Find mountpoints for subdirs
 use PTools::Time::Elapsed;                 # based on "cvt_secs_print()"

#my $TimeFmt = "%c";                        # 11/22/02 09:05:39
 my $TimeFmt = "%a, %d-%b-%Y %I:%M:%S %p";  # Wed, 22-Nov-2000 09:05:39 pm
 my $SysLog  = "/var/adm/syslog/syslog.log";
 my $Grep    = "/bin/grep";
 my $HostFQDN= PTools::Local->getFqdn();


sub new    { bless {}, ref($_[0])||$_[0] }
sub setErr { ( $_[0]->{STATUS}=$_[1]||0, $_[0]->{ERROR}=$_[2]||"" )       }
sub status { ( $_[0]->{STATUS}||0, $_[0]->{ERROR}||"" )                   }
sub stat   { ( wantarray ? ($_[0]->{ERROR}||"") : ($_[0]->{STATUS} ||0) ) }
sub err    { return($_[0]->{ERROR}||"")                                   }

sub startTime { return($_[0]->{Start} || 0) }
sub endTime   { return($_[0]->{End}   || 0) }
sub reportHost{ return( $HostFQDN     ||"") }

   *hasErrorsToReport = \&hasErrors;
   *noErrorsToReport  = \&noErrors;

sub hasErrors { return( keys %{ $_[0]->{Data} } ? 1 : 0 ) }
sub noErrors  { return( keys %{ $_[0]->{Data} } ? 0 : 1 ) }

sub collectData
{   my($self,$starttime,$syslogfile,$textString) = @_;

    ref $self or $self = $PACK->new;      # Class or object method
    $self->setErr(0,"");                  # Reset any prior error condition

    $syslogfile ||= $SysLog;
    $self->{SysLog} = $syslogfile;
    $textString ||= "vxfs: ";

    my $cmdObj = run PTools::Proc::Backtick($Grep, $textString, $syslogfile);

    my ($stat,$err) = $cmdObj->status;
    $stat = 0 if $stat == 256 and ! $err;     # Ran okay, just nothing grep'd

    $stat and $self->setErr($stat,$err);
    $stat  or $self->_parseData($cmdObj,$starttime);

    return($self,$stat,$err) if wantarray;
    return $self;
}

sub _parseData
{   my($self,$cmdObj,$starttime,@output) = @_;

    # Warning: Don't mess with this method without first 
    # understanding the "POE::Monitor::VxfsSyslog" class!
    # That class expects this method to understand three
    # different "signatures" (Normal, Hack1 and Hack2).

    if (! @output ) {
	ref $cmdObj and (@output) = split("\n", $cmdObj->result);
	ref $cmdObj  or (@output) = $cmdObj;
    }
    @output or return;
    $starttime ||= 0;

    $self->{Start}= $starttime;              # set temp value; reset below
    $self->{End}  = time();                  # set temp value; reset below

    my($key,@line,$logDate,$logTime);
    my($host,$error,$dev,$err,$path) = ();
    my($logStart,$logEnd) = ();
    my $DevHash = {};
    my $Data = {};

    foreach (@output) {
	#
	# Start with a simple match then, when the
	# record format is determined, parse it out.
	#
	if ( m#^\d{8,}:\d{8,}:# ) {                    # Format 0:  pre-parsed

	    my($unused);
	    ($logTime,$unused,$host,$dev,$error,$path,$unused) = split(':');
	    $DevHash->{$dev} = 1;

	} elsif ( m#vmunix: vxfs: mesg # ) {           # Format 1:  HP-UX 10.20

            m#(\w{3}\s*\d+\s\d\d:\d\d:\d\d) ([^\s]*) vmunix: vxfs: mesg \d+: ([^\s]*) - ([^\s]*) (.*)#;

            $logDate = $1 ||"";      # Note: in Perl5.6.1 "$1", etc. is local
            $host    = $2 ||"";
            $error   = $3 ||"";      # e.g., "vx_nospace"
            $dev     = $4 ||"";      # e.g., "/dev/vb00/lvol4"
            $err     = $5 ||"";      # e.g., "file system full (1 block extent)

	    $logTime = str2time( $logDate );

	} elsif ( m#vmunix: msgcnt \d+ vxfs: mesg # ) {           # HP-UX 11.x

       	    m#(\w{3}\s*\d+ \d\d:\d\d:\d\d) ([^\s]*) vmunix: msgcnt \d+ vxfs: mesg \d+: ([^\s]*) - ([^\s]*) (.*)#;

            $logDate = $1 ||"";
            $host    = $2 ||"";
            $error   = $3 ||"";      # e.g., "vx_nospace"
            $dev     = $4 ||"";      # e.g., "/dev/vb00/lvol4"
            $err     = $5 ||"";      # e.g., "file system full (1 block extent)

	    $logTime = str2time( $logDate );

        } else {
            print "unknown log entry format found in $PACK\n";
	    print "$_\n\n";
	    next;
        }

        next unless $logTime > $starttime;
        $logStart ||= $logTime;

        $key = "$host:$error:$dev";

        if (defined $Data->{$key}) {
            $Data->{$key}->{last}  = $logTime;
            $Data->{$key}->{count}++;
        } else {
            $Data->{$key} = {};
            $Data->{$key}->{first} = $logTime;
            $Data->{$key}->{last}  = $logTime;
            $Data->{$key}->{count} = 1;
            $Data->{$key}->{path}  = $path ||"";
        }
    }
    # Note that "$logEnd" is the date of the last syslog
    # entry, not the time that the script ends. Both the
    # "$logStart" and "$logEnd" are Unix "epoch" values.
    #
    $logEnd = $logTime;

    $self->{Data} = $Data;
    $self->{Start}= $logStart if $logStart;
    $self->{End}  = $logEnd   if $logEnd;

    return $DevHash;
}

sub formatData
{   my($self,$raw) = @_;

    my($first,$last,$count,$elapse,$mesg);
    my($key,$host,$error,$dev,$path);
    my $Data     = $self->{Data};                   # collected data
    my $arrayRef = [];                              # formatted data

    # FIX: if no "$self->{Start} set "$startTime" to the date stamp 
    #      of the "syslog.log" file?
    #
    my $startTime = time2str($TimeFmt, $self->{Start} || 0   );  # Date::Format
    my $endTime   = time2str($TimeFmt, $self->{End}   || time);  # Date::Format
    my $text      = "";

    unless (defined $self->{SysLog}) {
	$self->{SysLog} = $SysLog;
    }
    #__________________________________________________________
    # Create a couple of utility objects the first time through
    # and cache them in case we pass this way again.

    my $mntObj = $self->{MnttabObj} || new PTools::SDF::File::Mnttab;
    my $etObj  = $self->{ElapseObj} || new PTools::Time::Elapsed;

    $self->{MnttabObj} ||= $mntObj;
    $self->{ElapseObj} ||= $etObj;
    #__________________________________________________________

    foreach $key (sort keys %$Data) {
        ($host,$error,$dev) = split(':', $key);

	$first  = $Data->{$key}->{first};
	$last   = $Data->{$key}->{last};
	$count  = $Data->{$key}->{count};
	$path   = $Data->{$key}->{path};

	$path ||= $mntObj->findMountDevice($dev) || "*unmounted*";
	$elapse = ( $first == $last ? "" : $etObj->granular($first, $last) );
	$mesg   = ( $elapse ? "$count times in $elapse" : "1 time" );

	$text  = "$first:$last:$host:$dev:$error:$path:$mesg" ."\n";
	$text  = $self->formatEntry( $text )     unless $raw;

	push @{ $arrayRef }, $text;
    }

    if (! $raw) {
	$text = "";      # Reset "$text" here or we'll get dups of the above!

	$text .= "  System: ". $self->reportHost ."\n";
	$text .= " Logfile: $self->{SysLog}\n";

	push @{ $arrayRef }, $text;
    }

    return $arrayRef;
}

sub formatEntry
{   my($self, @args) = @_;
    #
    # To allow flexability when reporting "raw" data collected, the
    # "@args" variable can be in either of the following formats:
    # .  "$first:$last:$host:$dev:$error:$path:$mesg"
    # .  ($first,$last,$host,$dev,$error,$path,$mesg)
    #
    return "" unless scalar @args;

    my($first,$last,$host,$dev,$error,$path,$mesg)= $self->expandEntry( @args );

    return "" unless $first;

    my $text  = "";
       $text .= "    Path: $host:$path\n";
       $text .= "  Device: $host:$dev\n";
       $text .= "   ERROR: $error\n";
       $text .= "   Found: $mesg\n";

    my $format1 = "%8s  %-30s\n";             # "MessageFmt" not "TimeFmt"
    my $format2 = "%18s  %-30s\n";            # "MessageFmt" not "TimeFmt"

    if ($first == $last) {
	##$text .= sprintf($format1,     "on", time2str($TimeFmt,$first) );

	$text .= "    Time: ". time2str($TimeFmt,$first) ."\n";
    } else {
	$text .= " Between: ". time2str($TimeFmt,$first) ."\n";
	$text .= "     and: ". time2str($TimeFmt,$last)  ."\n";

	#$text .= sprintf($format2,"between", time2str($TimeFmt,$first) );
	#$text .= sprintf($format2,    "and", time2str($TimeFmt, $last) );
    }
    $text .= "\n";

    return $text;
}

sub expandEntry
{   my($self, @args) = @_;
    #
    # To allow flexability when reporting "raw" data collected, the
    # "@args" variable can be in either of the following formats:
    # .  "$first:$last:$host:$dev:$error:$path:$mesg"
    # .  ($first,$last,$host,$dev,$error,$path,$mesg)
    #
    return "" unless @args;
    $args[1] or (@args) = split(':', $args[0]);

    return "" unless $#args == 6;      # FIX? handle other err types here?
    chomp($args[ $#args ]);            # strip any "\n" from "$mesg" here

    return( @args );
}

 use vars qw($first $last $host $dev $error $path $mesg);

sub parseEntry
{   my($self, $field, @args) = @_;
    #
    # $field must be one of "first" "last" "host" ... etc.
    #
    ($first,$last,$host,$dev,$error,$path,$mesg) = $self->expandEntry(@args);

    no strict "refs";

    return( ${$field} ||"" );
}

sub dump
{   my($self)= @_;
    my($pack,$file,$line)=caller();
    my $text  = "DEBUG: ($PACK\:\:dump)\n";
       $text .= "  self='$self'\n";
       $text .= "CALLER $pack at line $line ($file)\n";
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

ClearCase::Report::VxfsSyslog - Parse "vxfs" notification messages in syslog

=head1 VERSION

This document describes version 0.15, released October, 2004.

=head1 SYNOPSIS

        use ClearCase::Report::VxfsSyslog;

        my $reptObj = new ClearCase::Report::VxfsSyslog;

Collect any "vxfs" notifications from the system log file.

        $reptObj->collectData;

   or   ($stat,$err)     = $reptObj->collectData;

   or   $reptObj         = ClearCase::Report::VxfsSyslog->collectData;

   or   ($reptObj,$stat) = ClearCase::Report::VxfsSyslog->collectData;

   or   $reptObj->collectData( $starttime );

   or   $reptObj->collectData( $starttime, $syslogfile );

Report any "vxfs" notifications from the system log file.

        $arrayRef = $reptObj->formatData;
        print @{ $arrayRef };

   or   print @{ $reptObj->formatData };

   or   if ($reptObj->hasErrorsToReport) {
            print @{ $reptObj->formatData };
        } else {
            $reportHost = $reptObj->reportHost;
            print "$base: No errors to report on $reportHost.\n";
        }

=head1 DEPENDENCIES

Dependencies for this class include the following.

Date::Format, Date::Parse, PTools::Proc::Backtick, 
PTools::SDF::File::Mnttab and PTools::Time::Elapsed.

=head1 DESCRIPTION

This class collects B<vxfs> errors from the Unix system log file
which, by default, is "/var/adm/syslog/syslog.log".

=head2 Constructor

=over 4

=item collectData ( [ StartTime ] [, SysLogFile ] [, TextString ] ) 

Collect any B<vxfs> errors from the system log file.

=over 4

=item StartTime

If a B<StartTime>, in Unix "epoch" format, is passed the parser
will ignore any errors that occur prior to this time. This is 
handy when running this script on a schedule so as to prevent
duplicate notification of errors that have already been reported.

=item SysLogFile

Read an alternate B<SysLogFile>. By default the Unix system log file
named "/var/adm/syslog/syslog.log".

=item TextString

Pass a B<TextString> to look for alternate error strings in the B<SysLogFile>.
By default the parser looks for the string "vxfs: ".

=back

Example:

 use ClearCase::Report::VxfsSyslog;

 $reptObj = new ClearCase::Report::VxfsSyslog;

=back

=head2 Methods

=over 4

=item formatData ( Flag )

Returns a reference to an array of zero or more lines of formated data 
collected from the system log file.

=over 4

=item Flag

When any non-null B<Flag> value is passed, this method returns
"raw" colon-separated data suitable for logging or other formatting.

Without a B<Flag> value this module returns zero or more lines of
formatted output consisting of about four lines for each error detected.

=back

Example of printing formatted data:

 print @{ $reptObj->formatData };


Example of printing "raw" data:

 $arrayRef = $reptObj->formatData( "raw" );

 print @{ $arrayRef };


=item formatEntry ( Args )

This is the method that turns "raw" data collected from the system
log file into formatted data as returned by the B<formatData> method.

=over 4

=item Args

To allow flexability when formatting "raw" data collected, the
B<Args> variable can be in either of the following formats:

Either a string of colon-separated variables

 "$first:$last:$host:$dev:$error:$path:$mesg"

or a list of variables (this is the format of the "raw" output
from the B<formatData> method).

 ($first,$last,$host,$dev,$error,$path,$mesg)

=back

Example:

 $arrayRef = $reptObj->formatData( "raw" );

 foreach $entry ( @$arrayRef ) {
     print $reptObj->formatEntry( $entry );
 }

=item startTime

This method returns a timestamp (Unix "epoch" format) corresponding
to the first log entry processed in the syslog file. This is B<not>
the time the script started.

 $firstLogEntryTime = $reptObj->startTime;

=item endTime

This method returns a timestamp (Unix "epoch" format) corresponding
to the last log entry processed in the syslog file. This is B<not>
the time the script ended.

This value is handy to save, in a file for example, and then used
as the B<StartTime> parameter to the B<collectData> method during
the next run of a reporting script.

 $lastLogEntryTime = $reptObj->endTime;

=item reportHost

This method returns the hostname of the machine on which the data
is collected, which is handy when collecting raw data into a single
log file for multiple hosts. This returns the fully qualified domain
name ("fqdn").

 $hostname = $reptObj->reportHost;

=item hasErrors

=item hasErrorsToReport

=item noErrors

=item noErrorsToReport

Determine if this module collected any errors to report.

   if ( $reptObj->hasErrorsToReport ) {

       $arrayRef = $reptObj->formatData( $formatFlag );
       print @{ $arrayRef };

   } elsif ( $reptObj->noErrorsToReport ) {

       $reportHost = $reptObj->reportHost;
       print "$base: No errors to report on $reportHost.\n";
   }

=item status

=item stat

=item err

Determine if the B<collectData> method detected any errors
while collecting error entries from the system log file.

 ($stat,$err) = $reptObj->status;

 $stat and die $err;

 $stat  = $reptObj->stat;           # scalar context returns status number
 ($err) = $reptObj->stat;           # array context returns error message

 ($err) = $reptObj->err;

=item dump

Display the contents of an object of this class. This is handy
during development / testing / debugging scripts using this module.

 print $reptObj->dump;

=back

=head1 INHERITANCE

None currently.

=head1 AUTHOR

Chris Cobb, E<lt>chris@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 2002-2004 by Hewlett-Packard. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
