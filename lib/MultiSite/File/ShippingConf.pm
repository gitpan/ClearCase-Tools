# -*- Perl -*-
#
# File:  MultiSite/File/ShippingConf.pm
# Desc:  A simple parser for the MultiSite store-and-forward config file
# Auth:  Chris Cobb <cobb@cup.hp.com>
# Date:  Thu Aug 02 14:14:50 2001
# Stat:  Prototype
#
# Note:  This class ISA PTools::SDF::INI which in turn ISA PTools::SDF::File 
#        class. We override some PTools::SDF::INI methods to load Atria's 
#        shipping.conf. Also, this class provides read-only access to the 
#        config file.
#
#        The Microsoft ".ini" format is as follows. If anyone can point
#        me to official documentation or specifications, I'd appreciate it.
#
#          [section-tag1]
#            param1=value1
#            param2=value2
#
#        This Class is a strange use of the INI format, but the MultiSite 
#        shipping configuration file is strange, too. The VARIABLE names are 
#        turned into INI "section tags," and the values are stored within the 
#        INI sections using the storage-class values. Any VARIABLE names that 
#        don't use a storage-class will have values in the "-default" class.
#        (This turns out to be a good thing, and will become clear below.)
#
#        The "_loadFileINI" and "get" methods in this class ensure that the
#        correct processing occurs for each VARIABLE, including the special
#        handling necessary for the "ROUTE" and "MAX-DATA-SIZE" params.
#  
# Synopsis:
#        use MultiSite::File::ShippingConf;
#
#        $shipconf = new MultiSite::File::ShippingConf;
#
#        @value = $shipconf->get('VARIABLE');
#  or    @value = $shipconf->get('VARIABLE', "storage-class");
#  or    @value = $shipconf->get('VARIABLE', "argument");
#
#        print $shipconf->dump;
#
# Note:  The "get" method used to return parameter values will return an 
#        array of any/all value(s) defined for any given parameter. This 
#        is also different from "normal" INI file usage, and it holds true
#        for *every* VARIABLE definition contained in objects of this class.
#
# This module is based on the following syntax for the shipping.conf file
#
# WARN:  This class supports but DOES NOT enforce syntax in the MultiSite
#        shipping.conf file, and assumes that parameters are set correctly. 
#        Also, the default values set for missing VARIABLEs is accurate as 
#        of the modification date of this class. Take care to ensure that 
#        assumptions made herein remain accurate! Caveat Programmer.
#
#                       storage
#             VARIABLE   class   Value(s)              Default value
# --------------------  -------  ------------------    -------------
#        MAX-DATA-SIZE    no     size [ k | m | g ]    2097151 k 
# NOTIFICATION-PROGRAM    no     program-pathname      $AtriaBin/notify
#        ADMINISTRATOR    no     e-mail-address        root
#          STORAGE-BAY    yes    directory-pathname
#           RETURN-BAY    yes    directory-pathname
#           EXPIRATION    yes    number-of-days        14
#                ROUTE    no     next-hop  host...
#   (*)  ROUTE-THROUGH    no     host  next-hop...
#      RECEIPT-HANDLER    yes    program-pathname
#   CLEARCASE_MIN_PORT    no     from 49151 to 65535
#   CLEARCASE_MAX_PORT    no     from 49151 to 65535
#     DOWNHOST-TIMEOUT    no     minutes
#
# (*) Note the item "ROUTE-THROUGH." This is not stored in the Shipping.conf
# file. However, since the information necessary is already parsed while
# loading the data file, this variable is added for convenience.
#
# NOTE: the "ROUTE" directive(s) are specified somewhat differently in
# the configuration file and, therefore, must be parsed differently.
# Basically, we reverse the list so that it fits into the INI paradigm.
#
# The file:      ROUTE <next-hop> <hostA> <hostB> ...
#                ROUTE <dflt-hop> -default
#
# The object:    [ROUTE]
#                    -default = <dflt-hop>
#                    hostA    = <next-hop>
#                    hostB    = <next-hop>
#
# This way, the "get" method will return reasonable values, and will work
# the same with the ROUTE variable as for any other VARIABLE. For example,
#
#        $dflt-route  = $shipconf->get('ROUTE');
#        $next-hop    = $shipconf->get('ROUTE', "hostA");
#
# In addition, since the necessary information is at hand, this class builds
# a new INI section that contains each of the hosts for a given <next-hop>
#
#                [ROUTE-THROUGH]
#                    next-hop = hostA hostB
#
#        @host-list   = $shipconf->get('ROUTE-THROUGH', "next-hop");
#
# Remember, as noted above, that the "get" method returns an *array* of
# any/all value(s) defined for a given parameter.
#

package MultiSite::File::ShippingConf;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.06';
 @ISA     = qw( PTools::SDF::INI );

 use PTools::SDF::INI;                  # Inherits from PTools::SDF::INI

my($ShipConf,$Notify);

if (-d "/opt/rational/clearcase") {
    $Notify   = "/opt/rational/clearcase/bin/notify";
    $ShipConf = "/var/adm/rational/clearcase/config/shipping.conf";
} else {
    $Notify   = "/usr/atria/bin/notify";
    $ShipConf = "/var/adm/atria/config/shipping.conf";
}


sub new
{   my($class,$file) = @_;

    $file ||= $ShipConf;              # allow default filename

    my($self,$stat,$err) = $PACK->SUPER::new($file);

    return($self,$stat,$err) if wantarray;
    return $self;
}

sub get
{   my($self,$section,$param) = @_;

    $section = uc $section;
    if ($section eq "ROUTE" && ! defined $self->{$section}{$param}) {
	#
	# special handling for undefined ROUTEs: if there is no "ROUTE" 
	# defined for the current $param, force the -default "param".
	# However, if there is NO "-default ROUTE" defined, then the
	# host specified in $param routes directly to itself.
	#
        if (defined $self->{$section}{-default}) {
	    $param = "-default";
	} else {
	    return $param;
	}
    } 
    if ($section eq "ROUTE-THROUGH" && ! defined $self->{$section}{$param}) {
	#
	# special handling for undefined ROUTE-THROUGH params: if there is
	# no "ROUTE" for the current $param AND there is no "-default ROUTE"
	# the host specified in $param routes to itself. Otherwise, there
	# are NO hosts routed through $param, not even itself.
	#
	if ( (! defined $self->{ROUTE}{$param}) 
	and  (! defined $self->{ROUTE}{-default}) ) {
	    return $param;
	}
    }
    $param ||= "-default";         # If still no param, force "-default"

    ## return "Error: 'get' method requires array context in '$PACK'"
    ##    unless wantarray;
    ## return split(" ", $self->recParam($section,$param));

    my(@result) = split(" ", $self->recParam($section,$param) ||"" );
    return(wantarray ? @result : $result[0]);
}


# The following PTools::SDF::INI:: methods are overridden in this package.

sub param
{   $_[0]->setError(-1, "The 'param' method is disabled in '$PACK'");
    return($_[0]->ctrl('status'),$_[0]->ctrl('error')) if wantarray;
    return $_[0]->ctrl('status');
}

sub save 
{   $_[0]->setError(-1,
        "You REALLY don't want to rewrite the '$ShipConf' file in '$PACK'");
    return($_[0]->ctrl('status'),$_[0]->ctrl('error')) if wantarray;
    return $_[0]->ctrl('status');
}

sub _loadFileINI
{   my($self,$mode,$fd) = @_;

    my($section,$param,@args,$nextHop,%dataFields) = ();

    # Add any VARIABLE name that requires a <storage-class> argument.
    #
    my(@storageClassVars) = qw(
	STORAGE-BAY  RETURN-BAY  RECEIPT-HANDLER  EXPIRATION-PERIOD
			    );

    # The following table is used to convert the MAX-DATA-SIZE
    # parameter into bytes. This is due to the variable format
    # allowed in the conf file.
    my %multiplier = (
           # (see "http://www.firmware.com/support/bios/metric.htm")
	       k => 1024,                 # kilobyte is 2**10 bytes
	       m => 1048576,              # megabyte    2**20
	       g => 1073741824,           # gigabyte    2**30
	   ##  t => 1099511627776,        # terabyte    2**40  # the rest of
	   ##  p => 1125899906842620,     # petabyte    2**50  # these are not
	   ##  e => 1.15292150460685e+18, # exabyte     2**60  # (yet) valid
	   ##  z => 0,                    # zettabyte   2**70  # values for
	   ##  y => 0,                    # yottabyte   2**80  # this param.
		   );

    while(<$fd>) {

	next if /^(\s*)#|^(\s*)!|^(\s*);|^(\s*)$/;   # skip comments, empties
	chomp;

	(@args) = /\s*([^\s]*)/g;                    # collect all arguments
    	pop @args if $args[$#args] eq "";            # fix the pattern match?

	$section = shift @args;                      # VARIABLE is first arg

	if ($section eq "ROUTE") {
	    # reverse the handling of ROUTE directives so
	    # that the arguments work w/in the INI format
	    # (see additional notes, above).

	    $nextHop = shift @args;
	    foreach $param (@args) {
	        next unless $param;
	       ## defined $self->{$section}{$param} 
	       ##   or $self->{$section}{$param} = [];
	       ## push @{ $self->{$section}{$param} }, $nextHop;
	        $self->{$section}{$param} = $nextHop;

	       #print "section='$section'  host='$param' nextHop='$nextHop'\n";
		next if $param eq "-default";

	        if (defined $self->{"ROUTE-THROUGH"}{$nextHop}) {
	            $self->{"ROUTE-THROUGH"}{$nextHop} .= " $param";
		} else {
	            $self->{"ROUTE-THROUGH"}{$nextHop} = "$param";
		}
	    }

	} else {

	    if ($section eq "MAX-DATA-SIZE") {
	        # special handling for MAX-DATA-SIZE directives: since
		# the config file allows a "k", "m" or "g" suffix,
		# convert the parameter to bytes here. Yuck.

		my($arg,$unitSymbol) = ();

		# Handle both cases of: "NNx" and "NN  x"
		#
		if ($#args > 0) {
		    $unitSymbol = pop @args;
		} else {
		    ($arg,$unitSymbol) = $args[0] =~ m#(\d*)(\w)$#;
		    $unitSymbol and $args[0] = $arg;      # make args[0] numeric
		}

		# The default unit symbol is "k"
		#
		defined $multiplier{$unitSymbol} or $unitSymbol = "k";

		# NOTE: MAX-DATA-SIZE is converted to BYTES here
		#
		$args[0] = $args[0] * $multiplier{$unitSymbol};
	    }

	    # Set a "storage-class" for all vars in the config file.
	    # For those parameters where a "-default" parameter is
	    # NOT valid, set one anyway. This allows us to force the
	    # "default" response when no storage-class is passed via
	    # the "get" method, and everything hangs together nicely.
            #
	    if (grep /^$section$/, @storageClassVars) {
	        $param = shift @args;
	    } elsif ($args[0] eq "-default") {
	        $param = shift @args;
	    } else {
	        $param = "-default";
	    }
	    #__________________________________________________________
	    # Here we decide if we want to use an anonymous array
	    # or a simple space-separated list. If we use the array,
	    # then modify the "get" method, above, and replace the
	    # PTools::SDF::INI "dump" method to expand the values.

	   ## defined $self->{$section}{$param} or $self->{$section}{$param}=[];
	   ## push @{ $self->{$section}{$param} }, @args
	   ##     unless $section eq "ROUTE";

	    defined $self->{$section}{$param}
		and $self->{$section}{$param} .= " ";

	    $self->{$section}{$param} .= join(" ", @args);
	    #__________________________________________________________

	    #print "sec='$section' param='$param' args='", join("', '",@args),"\n";
	}
	$dataFields{$section} = 1;

    }

    # Refer to "ct man shipping.conf" for current default settings
    #
    defined $self->{"ADMINISTRATOR"}{-default}
         or $self->{"ADMINISTRATOR"}{-default}= "root";

    defined $self->{"EXPIRATION"}{-default}
         or $self->{"EXPIRATION"}{-default}   = "14";

    defined $self->{"MAX-DATA-SIZE"}{-default}
         or $self->{"MAX-DATA-SIZE"}{-default}= "2097151" * $multiplier{"k"};

    defined $self->{"NOTIFICATION-PROGRAM"}{-default}
         or $self->{"NOTIFICATION-PROGRAM"}{-default} = $Notify;

    # a little final housekeeping
    #
    if (defined $self->{"ROUTE"}) {
	my $dfltRoute =  $self->{"ROUTE"}{-default} ||"";
	$dfltRoute and $self->{"ROUTE-THROUGH"}{$dfltRoute} = "-default";
	$dataFields{'ROUTE-THROUGH'} = 1;
    }
    $self->ctrl('dataFields', sort keys %dataFields);
    $self->ctrl('readOnly',   "Save method is disabled for this file.");

    return;
}
#_________________________
1; # Required by require()

__END__

=head1 NAME

MultiSite::File::ShippingConf - A simple parser for the MultiSite store-and-forward config file

=head1 VERSION

This document describes version 0.06, released May, 2004.

=head1 SYNOPSIS

       use MultiSite::File::ShippingConf;

       $shipconf = new MultiSite::File::ShippingConf;

       @value = $shipconf->get('VARIABLE');
  or   @value = $shipconf->get('VARIABLE', 'storage-class');
  or   @value = $shipconf->get('VARIABLE', 'argument');

       print $shipconf->dump;

=head1 DESCRIPTION

This class is an object oriented wrapper for the 'B<Shipping.conf>'
file use to configure Rational Software's MultiSite (ClearCase)
environment.

Objects of this class load the 'B<Shipping.conf>' file into an 'B<INI>'
file format (Microsoft's Windowz '.INI' format). Currently this class
provides read only access to the MultiSite shipping configuration file.

The Microsoft '.ini' format is as follows. If anyone can point
me to official documentation or specifications, I'd appreciate it.

       [section-tag1]
       param1=value1
       param2=value2

This Class is a strange use of the INI format, but the MultiSite 
shipping configuration file is strange, too. The VARIABLE names are 
turned into INI 'section tags,' and the values are stored within the 
INI sections using the storage-class values. Any VARIABLE names that 
don't use a storage-class will have values in the '-default' class.
(This turns out to be a good thing, and will become clear below.)

=head2 Constructor

=over 4

=item new ( ConfigFile )

Load the MultiSite shipping configuration file into memory. By default,
this file is named B<shipping.conf>. It's location depends on the installed
version of ClearCase/MultiSite.

Through versions 5.x, this file is located in 'B</var/adm/atria/config/>'.
For versions 6 and later, this file is located in
'B</var/adm/rational/clearcase/config/>'.

       use MultiSite::File::ShippingConf;

       $shipconf = new MultiSite::File::ShippingConf;

=over 4

=item ConfigFile

Load a MultiSite shipping configuration file from an alternate location.

=back

       $shipconf = new MultiSite::File::ShippingConf( $altConfigFile );

=back


=head2 Methods

=over 4

=item get ( Variable [, StorageClass ] )

The B<get> method used to return parameter values will return an array of 
any/all value(s) defined for any given parameter. This is different from 
'normal' INI file usage, and it holds true for I<every> B<Variable> definition 
contained in objects of this class.

=over 4

=item Variable

Valid B<Variable> parameters and default values, if any, are as follows.
(The value for I<$AtriaBin> varies with the installed version of MultiSite.)

                        Storage
              Variable   Class   Value(s)              Default value
  --------------------  -------  ------------------    -------------
         MAX-DATA-SIZE    no     size [ k | m | g ]    2097151 k 
  NOTIFICATION-PROGRAM    no     program-pathname      $AtriaBin/notify
         ADMINISTRATOR    no     e-mail-address        root
           STORAGE-BAY    yes    directory-pathname
            RETURN-BAY    yes    directory-pathname
            EXPIRATION    yes    number-of-days        14
                 ROUTE    no     next-hop  host...
    (*)  ROUTE-THROUGH    no     host  next-hop...
       RECEIPT-HANDLER    yes    program-pathname
    CLEARCASE_MIN_PORT    no     from 49151 to 65535
    CLEARCASE_MAX_PORT    no     from 49151 to 65535
      DOWNHOST-TIMEOUT    no     minutes


B<(*)> Note the item 'B<ROUTE-THROUGH>.' This is not stored in the 
B<Shipping.conf> file. However, since the information necessary is 
already parsed while loading the data file, this variable is added 
for convenience. See Examples, below.

=item StorageClass

Multiple B<Variable> parameters may be configured using a so-called
B<StorageClass> to define additional configuration values for some
of the items in this data file.

To see a complete list of the values stored in any shipping.conf file,
use the B<dump> method. This is useful when testing and debugging scripts
that create objects of this class.

=back

Examples:

  $dflt_route  = $shipconf->get('ROUTE');

  $next_hop    = $shipconf->get('ROUTE', 'hostA');

  (@host_list) = $shipconf->get('ROUTE-THROUGH', $next_hop);

  print $shipconf->dump;

=back

=head1 WARNING

This class supports but DOES NOT enforce syntax in the MultiSite
shipping.conf file, and assumes that parameters are set correctly.
Also, the default values set for any undefined B<Variable> is accurate
as of the modification date of this class. Take care to ensure that
assumptions made herein remain accurate! Caveat Programmer.

=head1 INHERITANCE

This class inherits from PTools::SDF::INI which in turn inherits from 
PTools::SDF::File. Due to the strange format of the 'shipping.conf' file 
this class overrides some of the PTools::SDF::INI methods to correctly 
parse parameters in the data file.

=head1 SEE ALSO

For additional methods see L<PTools::SDF::INI> and L<PTools::SDF::File>.

=head1 AUTHOR

Chris Cobb, E<lt>chris@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 2002-2004 by Hewlett-Packard. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
