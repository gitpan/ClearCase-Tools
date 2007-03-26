# -*- Perl -*-
#
# File:  ClearCase/Proc/ClearTool.pm
# Desc:  OO wrapper for Rational's cleartool/multitool command interpreters
# Auth:  Chris Cobb <cobb@cup.cup.hp.com>
# Date:  Fri Dec 07 13:35:01 2001
# Stat:  Prototype
#
# Abstract:
#        This class will run a ClearCase "cleartool" or "multitool"
#        command interpreter as a child process. Sub-commands are
#        invoked and output is returned via the "run" method. This 
#        improves overall performance as a new command interpreter
#        is not started for each and every sub-command.
#
#        A persistent process is also necessary when running the
#        "setenvent" sub-command to modify the date/user/group of
#        various VOB modification transactions. A "setenvent" will
#        only last for the duration of a single cleartool process.
#
# Usage:
#        use ClearCase::Proc::ClearTool;
#        $cleartool  = new ClearCase::Proc::ClearTool;
#        $result     = $cleartool->run("lsvobs -s -host $hostname");
#        ($stat,$err)= $cleartool->status;
#
#    or  use MultiSite::Proc::MultiTool;
#        $multitool  = new MultiSite::Proc::MultiTool;
#        $result     = $multitool->run("lsreplica -l -invob $vobtag");
#        ($stat,$err)= $multitool->status;
#
#
#        $cleartool->setevent($date, $uname);
#    or  $cleartool->setevent($date, $uname, $gname, $userName, $hostName);
#
#        $cleartool->unsetevent;
#    or  $cleartool->setevent("unset");
#
#  For Dependencies, Synopsis and further details, including parsing
#  the resulting output and notes on the "setevent" sub-command, see 
#  additional documentation included after the end of this module.
#

package ClearCase::Proc::ClearTool;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw($VERSION @ISA $Ok $True $NotOk $False);
 $VERSION = '0.13';
#@ISA     = qw( );

 use Date::Format;                      # time2str( $dateFormat, $time );
 use IO::Pipe;                          # interface to Pipe descriptiors
 use POSIX qw( errno_h );               # defines EAGAIN, among others

 my $AtriaHome;
 if (-d "/opt/rational/clearcase") {
     $AtriaHome    = "/opt/rational/clearcase";   # home location for V6+
 } else {
     $AtriaHome    = "/usr/atria";                # home location for V2+
 }
 my $AtriaBin     = "$AtriaHome/bin";   # used to run cleartool/multitool
 my $AtriaJava    = "$AtriaHome/java";  # used to check for CC V.5+
 my $NoCmdStatus  = 0;                  # set via "use"/"import"

 $Ok    =  $True  = 1;                  # some truths, and
 $NotOk =  $False = 0;                  # some falsehoods


# WARN: Now that this module supports the "-status" mode (available
# with CC V.5 and later) the possibility of "hanging" the child
# ct/mt process has been reintroduced. Unfortunately, we can NOT
# use the simple work around that was available when using the "EOD"
# string to delimit commands with earlier versions of ct/mt.
#
# If the "$AtriaJava" path exists, either as as subdir or a symlink,
# then we are running ClearCase V.5 or later and WILL use the "-status"
# option when we start the ct/mt co-process UNLESS we are told otherwise. 
#
# To force ct/mt commands V.5 and later to NOT use the "-status"
# mode, add a "noCmdStatus" parameter to the "use" statement,
# or pass the same parameter to the "new" or "start" methods.
# Any one of the following are equivalent in this functionality.
#
#   use ClearCase::Proc::ClearTool qw( noCmdStatus );
#
#   $cleartool = new ClearCase::Proc::ClearTool("","noCmdStatus");
#
#   $cleartool->start("","noCmdStatus");
#
sub import
{   my($class,@args) = @_;
    $args[0] and ( $args[0] =~ /noCmdStatus/i ? $NoCmdStatus = 1 : 0 );
    return;
}

sub new
{   my($class,$prog,$useCmdStatus) = @_;

    bless my $self = {}, ref($_[0])||$_[0];

    # If "nostart" flag passed in "$prog", don't start the child process.
    # When this happens, any calls to the "run" method will fail until
    # the "start" method has been called successfully.
    #
    $prog ||= "";

    $self->set('_noCmdStatus', $NoCmdStatus);    # global set via "use"

    $self->start($prog, $useCmdStatus) unless $prog =~ /no(start|child|ne)?/i;

    return( $self, $self->status ) if wantarray;
    return( $self );
}


# Note that the syntax for the "setErr" method both sets and returns
# the "status" and "error" values. This is an intended side-effect.

sub set    { $_[0]->{$_[1]}=$_[2] ||""    }   # Note that the 'param' method
sub get    { return( $_[0]->{$_[1]} ||"" ) }  #    combines 'set' and 'get'
sub param  { $_[2] ? $_[0]->{$_[1]}=$_[2] : return( $_[0]->{$_[1]} ||"" )  }
sub setErr { $_[0]->{"status"}=$_[1] || 0, $_[0]->{"error"}=$_[2] || ""    }
sub status { return( $_[0]->{"status"}||0, $_[0]->{"error"}||"" )          }
sub stat   { (wantarray ? ($_[0]->{"error"}||"") : ($_[0]->{"status"}||0)) }
sub err    { return( $_[0]->{"status"} ? $_[0]->{"error"} || "" : "" )     }
sub warn   { return( $_[0]->{"status"} ? "" : $_[0]->{"error"} || "" )     }
sub result { return( $_[0]->{"result"} ) }

   *started = \&isRunning;

sub isRunning    { return( defined $_[0]->{parent2child}  ? 1 : 0 ) }
sub useCmdStatus { return( $_[0]->get('_useCmdStatus') ) }
sub lastCmdNum   { return( $_[0]->get('lastCmdNum')    ) }
sub setStatOnly  { $_[0]->{"status"}=$_[1] || 0          }
sub rawOutput    { return( $_[0]->get('rawOutput')     ) }

sub errorMessage
{   my($self) = @_;

    my($stat,$err) = $self->status;
    return "" unless $stat;

    my($pack,$file,$line) = caller();
    my $text;
    $text .= "\n$err\n";
    $text .= "\nError detected at line $line of package $pack\n";
    $text .= "(in file '$file')\n";

    return($text);
}

sub parser 
{   my($self,$parser,$parse) = @_;

    $parser or return( $self->get("parser"), $self->get("parse") );

    $parse ||= "";
    $self->set("parser", $parser);         # need a class or an object here
    $self->set("parse",  $parse);          # method validation performed later

    return;
}

# Define a string that should not be output by cleartool or multitool
my $EOD = "--EOD--EOD--EOD--";

sub run                                    # run a cleartool/multitool sub-cmd
{   my($self,$cmd,$parser,$parse) = @_;

    $self->setErr(0,"");

    # Attempt to collect our output and input pipe descriptors
    #
    my $p2c = $self->get("parent2child");  # writer
    my $c2p = $self->get("child2parent");  # reader

    # Verify that a child process was successfully started ...
    #
    return("", $self->setErr(-1,"No child process available in '$PACK' class"))
	unless $p2c;

    # Are we parsing the output? A "$parser" parameter here
    # overrides any default set via the "parser" method. Use
    # a param of "noparse" to skip using the default parser.
    # For the parameter, a class or an object is ok here.
    #
    $parser||= $self->get("parser");
    $parser  = "" if $parser eq "noparse";
    my @data = ();

    if ($parser) {
    	$parse ||= $self->get("parse");    # check for a pre-set parser method
    	$parse ||= "parse";                # default parser method (if parsing)
	$parser->can($parse) or
	    return("", $self->setErr(-1,"The '$parse' method for '$parser' class is not valid in '$PACK'") );
    }

    # For ClearCase Versions PRIOR to V.5:
    # Send "$cmd" to 'cleartool' (or multitool) process and immediately 
    # send a second command to echo a unique string. This will be used 
    # to indicate end of data. Don't   print $p2c "!echo $EOD\n"   or
    # we're right back to spawning a shell for every sub-cmd. Additional
    # newlines are pre-pended to the EOD string to help avoid I/O hangs.
    #
    # For ClearCase Versions V.5 and Later:
    # The "-status" cmd-line option was used in the "start" method. This
    # provides a much easier way to synchronize commands. However, when
    # running in this mode, it is up to the CALLING MODULE to ENSURE the
    # "$cmd" parameter IS COMPLETE. If, for example, an "rmelem" command
    # is used w/o the "-f" parameter, the "$cmd" string MUST then include
    # a trailing "\nyes" OR THIS MODULE WILL HANG. We could work around this
    # situation using the EOD string, but we CAN NOT WORK AROUND THIS NOW.
    #
    my $useCmdStatus = $self->get('_useCmdStatus');    # is CC V.5 or later?

    # print "DEBUG: cmd='$cmd'\n";

    print $p2c "$cmd\n";
    print $p2c "\n\n$EOD\n"  unless $useCmdStatus;     # parse Status? or EOD?

    # Next, read the resulting output from 'cleartool' (or multitool)
    # until we get our end of data marker.
    #
    $self->set("result",    "");
    $self->set("rawOutput", "");
    my $line = "";

    my $partialLine = "";

    while( defined($line=<$c2p>) ) {
	#print "DEBUG: line='$line'\n";

        # Look for special string indicating end of output from the cmd
	# WARNING: This may or may not be on a line by itself! If not,
	# make sure to collect any "partial line" output and save it.
	#
	if ( $useCmdStatus && $line =~ /^(.*)?Command (\d+) returned status (\d+)/) {
	    $self->set('lastCmdNum', $2 );    # Keep track of cmd numbers.
	    $self->setStatOnly( $3 );         # ENSURE correct attr is set!

	    $partialLine = $1;                # collect here, save below
	    last;

	} elsif ( $line =~ /^(.*)(clear|multi)tool: .*$EOD/ ) {
	    $partialLine = $1;                # collect here, save below
	    last;
	}
	$self->{"rawOutput"} .= $line;

        # Warning detected ... append to any prior warn/error.
	# FIX: return a "+1" here? or stay with "0" when no prior status?
	# (If this changes, update the "warn" and "err" methods.)
	#
        if ($line =~ /^(clear|multi)tool: Warning:/) {
	    chomp($line);
	    my($stat,$msg) = $self->status;
	    $msg and ($line = "$msg\n$line");
	    $self->setErr($stat,$line);         # $stat = 0 or prior "-1"
	    next;
	}

        # Error detected ... append to any prior warn/error.
	#
        if ($line =~ /^(clear|multi)tool: Error:/) {
	    chomp($line);
	    my($stat,$msg) = $self->status;
	    $msg and ($line = "$msg\n$line");
	    $self->setErr(-1,$line);            # set $stat = -1 here
	    next;
	}

        # Collect everything else as the result.
	if ($parser) {
	    chomp($line);
	    push @data, $line;
	} else {
	    $self->{"result"} .= $line;   # FIX: use a method for this.
	}
    } # END of while( defined($line=<$c2p>) ) {

    if ($partialLine) {                   # collected above, saved here
	if ($parser) {
	    push(@data, $partialLine);
	} else {
	    $self->{"result"} .= $partialLine;
	}
	$self->{"rawOutput"} .= $partialLine;
    }

    my($stat,$err) = $self->status;
    if ($err and ! $stat) {
	my $progName = $self->get("progName") || "unknown";
	$self->setErr($stat,"progName: Error: An unknown error occurred in '$PACK' class");
    }

    # If we have an "Output Parser" class (or object), use it to parse
    # resulting output, but only when there is output. $self->{result}
    # will already have been reset above--no need to do so again here.
    #
    if ($parser and scalar @data) {
	my $tmpObj = $parser->$parse( @data );
	$self->set("result", $tmpObj);

	# FIX: add a "ct " or "mt " prefix to $cmd depending on child proc?
	#
	if ( ref($tmpObj) ) {
	    $tmpObj->setCmd( $cmd )           if $tmpObj->can("setCmd");
	    $tmpObj->setErr( $self->status )  if $tmpObj->can("setErr");
	}
    }
    return( $self->result, $self->status ) if wantarray;
    return( $self->result );
}


sub start                                 # start cleartool/multitool process
{   my($self,$prog,$useCmdStatus) = @_;
  
    $useCmdStatus ||= "";
    $self->setErr(0,"");

    # Verify that a child process does not already exist ...
    #
    return($self->setErr(-1,"A child process already exists in '$PACK' class"))
	if $self->get("parent2child");

    $prog ||= "$AtriaBin/cleartool";
    $prog   = "$AtriaBin/cleartool"  if $prog eq "cleartool";
    $prog   = "$AtriaBin/multitool"  if $prog eq "multitool";

    if ($prog =~ m#cleartool#) {
	$self->set("progName", "cleartool");
    } elsif ($prog =~ m#multitool#) {
	$self->set("progName", "multitool");
    } else {
	$self->set("progName", "unknown");
    }

    return $self->setErr(-1,"Error: Cannot exec '$prog' in '$PACK'")
	unless -x $prog;

    my $p2c = new IO::Pipe;        # Pipe 1: Parent Writes / Child Reads
    my $c2p = new IO::Pipe;        # Pipe 2: Parent Reads  / Child Writes

    $c2p or return $self->setErr( sprintf("Error (c2p): %d",$!), $! );
    $p2c or return $self->setErr( sprintf("Error (p2c): %d",$!), $! );

    my($chPid, $sleepCount) = (0,0);

    #____________________________________________________________________
    # If the "$AtriaJava" path exists, either as as subdir or a symlink,
    # then we are running ClearCase V.5 or later and can use the "-status"
    # option when running the cleartool child process. 
    #
    # Reminders
    # .  $NoCmdStatus   is set via "use" statement and "import" method
    # .  $useCmdStatus  is set via parameter passed to "new" or "start"
    #
    my( $lstat, $ccVer ) = (0,"");

    if ( lstat( $AtriaJava ) ) {
	$lstat = 1;
	$ccVer = "ClearCase v.5 or later";
    } else {
	$lstat = 0;
	$ccVer = "ClearCase pre v.5";
    }

    if ( $NoCmdStatus or ($useCmdStatus =~ /noCmdStatus/i) ) {
	$useCmdStatus = 0;

    } else {
	$useCmdStatus ||= $self->get('_useCmdStatus');

	if ( $useCmdStatus or $lstat ) {
	    $useCmdStatus = 1;
	}
    }
    $prog .= " -status"  if $useCmdStatus;   # A long road to this simple test!

    $self->set('_useCmdStatus', $useCmdStatus );
    $self->set('_ccVer',        $ccVer        );
    $self->set('_prog',         $prog         );

  # print $self->dump;          # DEBUG
    #____________________________________________________________________

 loop: {                      # Bare block to accomodate busy process table

    $chPid = fork();          # Attempt to create a child process

    if ( $chPid ) {                # Okay, in parent process

	$c2p->reader();            # parent reads from child
	$p2c->writer();            # parent writes to child
	$p2c->autoflush(1);        # Unbuffer the *writer*

        $self->set("parent2child", $p2c);
        $self->set("child2parent", $c2p);
	$self->set("childprocess", $prog);
	$self->set("childpid",     $chPid);

	return;

    } elsif (defined $chPid) {     # Okay, in child process

	$p2c->reader();            # child reads from parent
	$c2p->writer();            # child writes to parent
	$c2p->autoflush(1);        # Unbuffer the *writer*

	# Here we "dup"licate file handles ... or die trying
	# . redirect STDIN to read input from the "p2c" pipe
	# . redirect STDOUT and STDERR to write to "c2p" pipe
	#
	my $in = fileno($p2c);
	my $out= fileno($c2p);

	open(STDIN, "<&=$in")   or die "Error: can't dup STDIN in '$PACK': $!";
	open(STDOUT,">&=$out")  or die "Error: can't dup STDOUT in '$PACK': $!";
	open(STDERR,">&STDOUT") or die "Error: can't dup STDERR in '$PACK': $!";

	exec $prog   or die "Error: failed to 'exec $prog' in '$PACK': $!";

	# If exec returns, something went wrong ...
	# (in-line code here will trigger warnings when script run with "-w")

    } elsif ( $! == EAGAIN ) {     # EAGAIN - No more proocesses, recoverable
	($sleepCount++ == 5) and
	    return $self->setErr(-1,"Can't fork after 5 tries in '$PACK'");
	sleep 1;
	redo loop;

    } else {                       # Failed to create child process
	return $self->setErr(-1,"Can't fork child process in '$PACK': $!");
    }
  } # end of "loop:" bare block

    # Nothing should ever get this far ...
    # By now the parent has either returned an error,
    # the child died while trying to dup or exec, or
    # cleartool/multitool should be "exec'ed" and awaiting input.
}


# Define a DESTROY method alias to cleanly shutdown the child proc
# if/when an object variable of this class goes out of scope.
#
   *DESTROY   = \&stop;
   *exit      = \&stop;
   *terminate = \&stop;

sub stop                                  # terminate ct/mt child process
{   my($self) = @_;

    $self->setErr(0,"");

    my $p2c = $self->get("parent2child");
    my $c2p = $self->get("child2parent");

    # Verify that a child process was successfully started ...
    #
    return( $self->setErr(-1,"No child process to stop in '$PACK' class") )
	unless $p2c;

    print $p2c "exit\n";

    $p2c->close;
    $c2p->close;
    $! and $self->setErr( sprintf("%d",$!), $! );

    # Ensure that, when this method is not invoked during
    # object destruction, any further attempts to call the
    # "run" method will fail: no child process is active.
    #
    $self->set("parent2child", "");
    $self->set("child2parent", "");
    $self->set("progName",     "");

    return( $self->status ) if wantarray;
    return $NotOk if $self->stat;
    return $Ok;
}

 my $EventFormat = "%d-%b-%Y.%H:%M:%S";     # E.g.:  22-Apr-2002.22:34:58

sub geteventFormat { return( $EventFormat ) }

   *unsetevent = \&setevent;
   *resetevent = \&setevent;

sub setevent
{   my($self,$date,$uname,$gname,$userName,$hostName) = @_;
    #
    # The date param may be any of the following.
    # .  a Unix "epoch" date number 
    # .  a formatted "setevent" date string (see $EventFormat)
    # .  the string "-unset", a nul-string or undefined
    # When not running "-unset", $date and $uname are required.
    #
    $self->setErr(0,"");
    my $argStr = "";

    if (! $date or ($date =~ /^(-)?unset/) ) {
        $argStr .= "-unset";
    } else {
    	($date =~ /^\d*$/) and $date = time2str( $EventFormat, $date );
	$argStr .= "-time $date";                      # required
	$argStr .= " -user $uname"      if $uname;     # required
	$argStr .= " -group $gname"     if $gname;     # optional
	$argStr .= " -name '$userName'" if $userName;  # optional
	$argStr .= " -host $hostName"   if $hostName;  # optional
    }
    $self->run( "setevent $argStr", "noparse" );

    return( $self->status ) if wantarray;
    return $NotOk if $self->stat;
    return $Ok;
}

sub dump {
    my($self)= @_;
    my($pack,$file,$line)=caller();
    my $text  = "DEBUG: ($PACK\:\:dump)\n";
       $text .= "  self='$self'\n";
       $text .= "CALLER $pack at line $line ($file)\n";
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

ClearCase::Proc::ClearTool - OO interface to Rational's cleartool/multitool command interpreters

=head1 VERSION

This document describes version 0.13, released May, 2004.

=head1 DEPENDENCIES

Dependencies for this class include the following.

 1)  Rational's ClearCase "cleartool" and/or "multitool" commands

 2)  An operating system on which Perl can fork a child process.

 3)  File modules "IO-1.20" (or later) including
     IO::File, IO::Handle and IO::Pipe.

=head1 SYNOPSIS

      use ClearCase::Proc::ClearTool;
  or  use MultiSite::Proc::MultiTool;

      $cleartool = new ClearCase::Proc::ClearTool;
  or  $multitool = new MultiSite::Proc::MultiTool;

  or  $cleartool = new ClearCase::Proc::ClearTool("/path/to/cleartool");
  or  $cleartool = new ClearCase::Proc::ClearTool("nostart");

      ($result,$stat,$err) = $cleartool->run( $command_string );

  or  $result     = $cleartool->run( $command_string );
  or  ($stat,$err)= $cleartool->status;


  When the "new" method was called with a "nostart" parameter, the child
  cc/mt process must be started prior to calling the "run" method.

      $cleartool->start;
  or  $multitool->start;

  The "isRunning" method can be used to conditionally start the child cc/mt
  process, or otherwise determine if a child process is currently running.

      $cleartool->start  unless $cleartool->isRunning;
      $multitool->start  unless $multitool->isRunning;


  To disable use of the cc/mt "-status" mode with CC v.5 and later:

      use ClearCase::Proc::ClearTool qw( noStatusMode );
  or  use MultiSite::Proc::MultiTool qw( noStatusMode );

      $cleartool = new ClearCase::Proc::ClearTool( undef, "noStatusMode" );
  or  $multitool = new MultiSite::Proc::MultiTool( undef, "noStatusMode" );

  Or, when the "new" method was called with a "nostart" parameter,
  a "noStatusMode" parameter may be passed to the "start" method.

      $cleartool->start( undef, "noStatusMode" );
  or  $multitool->start( undef, "noStatusMode" );


=head1 DESCRIPTION

B<ClearCase::Proc::ClearTool> (or B<MultiSite::Proc::MultiTool>)
will run a ClearCase B<cleartool> (or B<multitool>) command interpreter
as a child process. Sub-commands are invoked and output is returned via 
the B<run> method. This improves overall performance as a new command 
interpreter is not started for each and every sub-command.

A persistent process is also necessary when running the B<setenvent> 
sub-command to modify the date/user/group of various VOB modification 
transactions. A B<setenvent> will only last for the duration of a single 
cleartool process. Further details on B<setevent> are included, below.

=head2 Constructor

=over 4

=item new ( [ { ProgName | 'nostart' } ] [, 'noStatusMode' ] )

Create a new B<cleartool> or B<multitool> child process.

=over 4

=item ProgName

This parameter is optional. When specified, it should be one of

 cleartool
 multitool
 /full/path/to/cleartool
 /full/path/to/multitool
 "nostart"

Use B<nostart> to delay launching the interpreter as a sub-process.

Otherwise B<ProgName> defaults to the appropriate interpreter, depending 
on the class used. Either class can run either interpreter but, for 
semantic clarity, the defaults should probably be used as shown in 
the B<Synopsis> section, above.

=item 'noStatusMode'

Pass a second parameter of 'B<noStatusMode>' to disable use of the 
cc/mt "-status" mode with CC v.5 and later. See the L<Warnings|warnings>
section, below, for further details.

=back

=back

=head2 Methods

=over 4

=item run ( Command )

Pass a B<cleartool> or B<multitool> sub-command to the child process.
While the following examples only show a B<$cleartool> object, 
B<$multitool> objects work in a corresponding manner.

 ($result,$stat,$err) = $cleartool->run( "lsvobs -s" );

For commands that require multiple lines of input, all of the
necessary input must be included in the cmd string. It is not
currently possible to pass I<additional> input to a sub-command
through subsequent calls to the B<run> method. E.g., to add the
necessary response for the I<rmelem> sub-command, use this.

 $cleartool->run( "rmelem $elem \nyes" );

Objects of this class ensure that the appropriate result of each
sub-command is returned to the calling script, and there should
not be any instances where i/o 'hangs' waiting for command output. 
I.e., this class will 'self synchronize' when reading from the
cleartool/multitool child, even when errors or warnings occur.

Omitting the '\nyes' response from the above command, for example,
should not cause scripts using objects of this class to hang.
However, in these types of cases, care should be taken by the user
to ensure that the command did complete successfully. No error msg
or status code will be available. Therefore, check the resulting 
text output (or test for existance of the element), etc.

(Of course, in the above example, it would be a better idea to add a
B<-force> option and omit the 'B< \nyes>' all together. The example
simply demonstrates the syntax necessary for multi line input.)


=item result

Collect the result of the previous B<cleartool>/B<multitool> command.
The result is also available via the B<run> command, above.

 $result = $cleartool->result;

=item status

=item stat

=item warn

=item err

Determine the status of the previous B<cleartool>/B<multitool> command.
The status is also available via the B<run> command, above.

 $cleartool->run("lsvob -s");
 ($stat,$err) = $cleartool->status;

 $stat  = $cleartool->stat;      # status number in scalar context
 ($err) = $cleartool->stat;      # error message in array context

Note: currently, when a I<Warning:> is emitted by B<cleartool> or
multitool, this is indicated by a value for B<$err> and a B<$stat>
of '0'. Use the following methods to test for errs and warns.

     $msg = $cleartool->warn;
 or  $msg = $cleartool->err;


=item exit

=item stop

=item terminate

Terminate the child process associated with the current object.
Either use the B<stop> method, undefine the object variable, or 
simply allow the object variable to fall out of scope. Of course,
after calling B<stop>, any calls to the B<run> method will fail.

     $cleartool->stop;
 or  ($stat,$err) = $cleartool->stop;

 or  undef $cleartool;
 or  die "<error condition>";
 or  exit;

=item start ( [ Command ] [, 'noStatusMode' ] )

Start/restart a child process for association with current object.
After invoking the B<stop> method it is possible to launch another
child process. The new child will have no relation to the original.

     $cleartool->start;
 or  $cleartool->start("/path/to/cleartool");
 or  $cleartool->start("/path/to/cleartool", "noStatusMode");

In addition, the B<start> method must be called if the B<new> method
was invoked in such a way that no child was started. For example,
to delay spawning the child when instantiating the object use this.

 $cleartool = new ClearCase::Proc::ClearTool("nostart");

And then, before a first call to the B<run> method, make sure that
the child process started successfully. 

 ($stat,$err) = $cleartool->start;
 $stat and die $err;

 $cleartool->run( $ctCommand );

The first parameter to the B<start> method is the same B<Command>
string as defined in the B<run> method. Optionally, 
pass a second parameter of 'noStatusMode' to disable use of the 
cc/mt "-status" mode with CC v.5 and later.


=item isRunning

=item started

Determine if a child process is currently running.

 $cleartool->start  unless $cleartool->isRunning;

=back

=head2 Parsing Output

=over 4

The most difficult part of scripting B<cleartool> and B<multitool>
commands is obtaining meaningful results from the output. As a data 
base query tool these commands leave much to be desired. To aleviate
the problem this class is designed to facilitate output parsing.

It is possible to pass a text parsing class to the B<run> method, 
the assumption being that this will instantiate an object. This 
is a parameter of the B<run> method since it is expected that the 
output from only some sub-commands will probably be parsed. The
parser class should have methods to B<parse>, B<set> and B<setErr>.

     use ClearCase::Vob::Info;
     $parser = "ClearCase::Vob::Info";       # parser as a class
 or  $parser = new ClearCase::Vob::Info;     # parser as an object

     $vobObj = $cleartool->run("lsvob -l", $parser);

     print $vobObj->dump;        # e.g., to display the results.

At this point, error conditions will be equivalent in the objects.

     ($stat,$err) = $cleartool->status;
 or  ($stat,$err) = $vobObj->status;
     

=item parser ( { ParserClass | ParserObject } )

A default parser class/object can be defined such that an extra
parameter is not required for the B<run> method. This will mean
that, for sub-commands where the resulting text is ignored, there 
will be a bit of extra overhead. For commands with no resulting 
outupt, there is no added overhead. The B<$parser> parameter passed
here is expected to be the same class or object as described above.

 $cleartool->parser( $parser );

To prevent parsing overhead when output will simply be ignored, 
add a B<noparse> parameter to the B<run> method. This way the default
parser is not invoked for a particular subcommand.

 $cleartool->run( $ctCommand, 'noparse' );

=back

=head2 Modifying Event Meta Data

It is possible to create a ClearCase object with modified date and
user info. To make this work, use the B<setevent> method just prior 
to a I<checkin> or other element creation event (I<mkbrtype>, etc.) 

=over 4

=item setevent ( Date, Uname [, Gname ] [, UserName ] [, HostName ] )

=item setevent ( 'unset' )

When calling the B<setevent> method the B<$date> parameter 
can be either a Unix I<epoch> date number or the normal setevent date
string as shown below.

Note that a setevent is only successful when the B<cleartool>
process is running as either the I<VOB owner> or I<root> (superuser). 

     $cleartool->setevent($date, $uname);
 or  $cleartool->setevent($date, $uname, $gname, $userName, $hostName);

=item unsetevent

The following is equivalent to running B<setevent( 'unset' )> 
as described above.

     $cleartool->unsetevent;
 or  $cleartool->setevent("unset");

=back

Additional notes on the B<cleartool> B<setevent> sub-command.

This is a sub-command recognized by B<cleartool> that allows creating
new VOB objects as if they were created at another time and/or by
another user. The syntax is as follows for B<cleartool> 4.2.

 Usage: setevent -time date-time -user login-name [-group group-name]
                 [-name user-full-name] [-host host-name]
        setevent [-unset]

Where a valid <date-time> consists of the following.

 <date-time> = <date>.<time> | <date> | <time> | "now" | "none"
 <date>      = d[d]-<month>[-[yy]yy] | <day-of-week> | "today" | "yesterday"
 <time>      = h[h]:m[m][:s[s]][UTC[+|-][h[h][:mm]]] (24-hour time)

Rational does not document this command. Testing shows the following:

 .  the cleartool process must be run by "root" or the "vob admin" user

 .  for the <login-name> and <group-name> parameters apparently a uid 
    or gid number works equally well (at least on HP-UX)

For B<file> and B<directory> elements:

 .  a "checkin" of the new element must complete successfully or the 
    modified meta-data will not be associated with the new element

 .  the "checkin" must complete before the cleartool process stops,
    or before the "-unset" option is used


=head1 INHERITANCE

The B<MultiSite::Proc::MultiTool> class inherits directly from this class.


=head1 WARNINGS

At version 0.10 of this module, it now supports the '-status' mode
(available with CC V.5 and later). B<The possibility of 'hanging' the 
child ct/mt process has been reintroduced.> Unfortunately, in 'status'
mode, we can I<no longer> use the simple work around that is still
available when not using the new status mode.

This module attempts to automatically detect ClearCase V.5 and later.
If the '/usr/atria/java' path exists, either as as subdir or a symlink,
then we are running ClearCase V.5 or later and B<will> use the '-status'
option when it starts the ct/mt co-process B<unless> it is told otherwise. 

To force ct/mt commands V.5 and later to B<not> use the '-status'
mode, add a 'B<noCmdStatus>' parameter to the 'use' statement,
or pass the same parameter to the 'new' or 'start' methods.
Any one of the following are equivalent in this functionality.

 use ClearCase::Proc::ClearTool qw( noCmdStatus );

 $cleartool = new ClearCase::Proc::ClearTool("","noCmdStatus");

 $cleartool->start("","noCmdStatus");

The only time that this script should experience a 'hang' situation
is when the calling script passes a badly formed ct/mt subcommand.
If the subcommand results in the ct/mt co-process issuing a prompt
for additional information then a hang will occur.

See the L<run|run> method, above, for examples of avoiding this
situation.


=head1 SEE ALSO

See L<MultiSite::Proc::MultiTool>, L<ClearCase::Vob::Info>
and L<ClearCase::Vob::Info::InfoBase>.

=head1 AUTHOR

Chris Cobb, E<lt>chris@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 2002-2004 by Hewlett-Packard. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
