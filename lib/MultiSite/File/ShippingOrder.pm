# -*- Perl -*-
#
# File:  MultiSite/File/ShippingOrder.pm
# Desc:  A simple parser for a MultiSite Shipping Order
# Auth:  Chris Cobb <cobb@cup.hp.com>
# Date:  Thu Jul 08 11:35:42 2004
# Stat:  Prototype
#
# Synopsis:
#        use MultiSite::File::ShippingOrder;
#
#        $shiporder = new MultiSite::File::ShippingOrder( $shipOrderFile );
#        $shiporder->stat and die $shiporder->err;
#
#        $count = $shiporder->count('VARIABLE');       # zero-based count
#
#        $arrayRef = $shiporder->getList('VARIABLE');
#        (@values) = $shiporder->getList('VARIABLE');
#
#        ($num,$str) = $shiporder->parseDate( $dateEntry );
#        $path = $shiporder->parsePath( $pathEntry );
#        ($host,$num,$str) = $shiporder->parseArrivalRoute( $arrivalEntry );
#
#        $hashRef = $shiporder->analyzeDeliveries;
#        print $shipObj->formatDeliveries( $hashRef );
#
#        $hashRef = $shipObj->analyzeFailedAttempts;
#        print $shipObj->formatFailedAttempts( $hashRef );
#
#        print $shiporder->dump;
#        print $shiporder->dump('verbose');
#
# Note:  The "get" method used to return parameter values will return an 
#        array of any/all value(s) defined for any given parameter.
#

package MultiSite::File::ShippingOrder;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.01';
 @ISA     = qw( MultiSite::Vob::Info::InfoBase );

 use MultiSite::Vob::Info::InfoBase;         # include parent class

sub new
{   my($class,$fileName) = @_;

    my $self = bless {}, ref($class)||$class;

    $self->loadFile( $fileName ) if $fileName;

    return $self;
}

sub loadFile
{   my($self,$fileName) = @_;

    -r $fileName or
	return $self->setErr(-1, "Can't read '$fileName' in '$PACK': $!");

    local(*IN);
    open(IN,"<$fileName") or
	return $self->setErr(-1, "Can't open '$fileName' in '$PACK': $!");

    my($attrName);

    $self->set('_fileName', $fileName);

    while( defined (my $line = <IN>) ) {

	if ($line =~ /^# Version (.*)/) {         # collect Version string

	    $self->set('Version', $1);

	} elsif ($line =~ /^(\s*)#|^(\s*)$/) {    # skip comments, empties
	    next;

	} elsif ($line =~ m#^%([^\s]*)\s?(.*)#) { # start of new Attribute

	    $attrName = $1;
	    $self->addList( $attrName, $2 ) if $2;

	} elsif ($line =~ /^\s*(.*)/) {           # add to current Attribute

	    $self->addList( $attrName, $1 );
	}
    }
    close(IN) or
	return $self->setErr(-1, "Can't close '$fileName' in '$PACK': $!");

    return;
}

#=======================================================================
#  Loading these strange files is easy ... parsing is a bit harder.    #
#=======================================================================

sub parsePath
{   my($self,$string) = @_;
  # print "DEBUG: string='$string'\n";
    my($str) = $string =~ m#"([^"]*)#g;
    return( $str );
}

sub parseDate
{   my($self,$string) = @_;
    my($num,$str) = $string =~ m#(\d*)\s(.*)#;
    return( $num, $str );
}

sub parseArrivalRoute
{   my($self,$string) = @_;
    my($host,$num,$str) = $string =~ m#^(\w*)\s(\d*)\s(.*)$#;
    return( $host, $num, $str );
}

sub parseDelivery
{   my($self,$string) = @_;
  # print "DEBUG: string='$string'\n";
    my($num,$str,$next,$dest) = $string =~ m#^(\d*)\s([^\s]*)\s([^\s]*)\s(.*)$#;
    return( $num, $str, $next, $dest );
}

sub analyzeDeliveries
{   my($self) = @_;

    my $attr  = "DELIVERIES";
    my $count = $self->count( $attr );
    return unless $count > -1;

    my($num,$str,$next,$dest);
    my($delivery,$hashRef);

    my $deliveries = $self->getList( $attr );

    foreach my $idx ( 0 .. $count ) {
	$delivery = $deliveries->[ $idx ];
	($num,$str,$next,$dest) = $self->parseDelivery( $delivery );
	$hashRef->{$next}++;
    }
    return $hashRef;
}

sub formatDeliveries
{   my($self,$hashRef) = @_;

    my $text;

    $text .= "Delivery Summary:\n";
    foreach my $host ( sort keys %$hashRef ) {
	$text .= "  $hashRef->{$host} deliveries via $host\n";
    }
    $text .= "\n";

    return $text;
}


sub parseFailedAttempt
{   my($self,$string) = @_;
    my($flag,$num,$str,$next,$dest) 
	= $string =~ m#^(\w)\s(\d*)\s([^\s]*)\s([^\s]*)\s(.*)$#;
    return( $flag, $num, $str, $next, $dest );
}

sub analyzeFailedAttempts
{   my($self) = @_;

    my $attr  = "FAILED-ATTEMPTS";
    my $count = $self->count( $attr );
    return unless $count > -1;

    my($flag,$num,$str,$next,$dest);
    my($failure,$hashRef);

    my $failedAttempts = $self->getList( $attr );

    foreach my $idx ( 0 .. $count ) {
	$failure = $failedAttempts->[ $idx ];

	($flag,$num,$str,$next,$dest) = $self->parseFailedAttempt( $failure );

	$hashRef->{$next}->{__total}++;
	$hashRef->{$next}->{__first} = $str unless $hashRef->{$next}->{__first};
	$hashRef->{$next}->{__last} = $str;
	$hashRef->{$next}->{$dest}++  if ($dest ne $next);
    }
    return $hashRef;
}

sub formatFailedAttempts
{   my($self,$hashRef) = @_;

    my $text;
    $text .= "Failure Summary:\n";
    foreach my $host ( sort keys %$hashRef ) {

	my $total = $hashRef->{$host}->{__total};
	my $first = $hashRef->{$host}->{__first};
	my $last  = $hashRef->{$host}->{__last};

	$text .= "  $total failures to $host\n";
	$text .= "     (between $first and $last)\n";
	my $destRef = $hashRef->{$host};

        foreach my $dest ( sort keys %$destRef ) {
	    next if $dest =~ /^__/;
	    $text .= "     $hashRef->{$host}->{$dest} destined for $dest\n";
	}
    }
    $text .= "\n";

    return $text;
}
#_________________________
1; # Required by require()

__END__

=head1 NAME

MultiSite::File::ShippingOrder - A simple parser for the MultiSite Shipping Order file

=head1 VERSION

This document describes version 0.01, released June, 2004.

=head1 SYNOPSIS

 use MultiSite::File::ShippingOrder;

 $shiporder = new MultiSite::File::ShippingOrder( $shipOrderFile );

 $shiporder->stat and die $shiporder->err;

 $count = $shiporder->count('VARIABLE');       # zero-based count

 $arrayRef = $shiporder->getList('VARIABLE');
 (@values) = $shiporder->getList('VARIABLE');

 $shiporder->parseDate( $dateEntry );
 $shiporder->parsePath( $pathEntry );
 $shiporder->parseArrivalRoute( $arrivalEntry );

 $hashRef = $shiporder->analyzeDeliveries;
 print $shipObj->formatDeliveries( $hashRef );

 $hashRef = $shipObj->analyzeFailedAttempts;
 print $shipObj->formatFailedAttempts( $hashRef );

 print $shiporder->dump;

=head1 DESCRIPTION

This class is an object oriented wrapper for a 'B<Shipping Order>'
file containing packet-specific details in Rational Software's 
MultiSite (ClearCase) environment.

=head2 Constructor

=over 4

=item new ( ShipOrderFile )

Load a MultiSite shipping order file into memory. It's location depends
on the installed version of ClearCase/MultiSite.

 use MultiSite::File::ShippingOrder;

 $shiporder = new MultiSite::File::ShippingOrder( $fileName );


=item parseDate

=item parsePath

=item parseArrivalRoute

These methods are defined to parse specific entries from
a given section within a shipping order file.

ToDo: Complete this discussion.

 $shiporder->parseDate( $dateEntry );

 $shiporder->parsePath( $pathEntry );

 $shiporder->parseArrivalRoute( $arrivalEntry );


=item analyzeDeliveries

=item formatDeliveries ( HashRef )

These methods are used to analyze and format information
pertaining to SUCCESSFUL deliveries of the data packet
associated with the current shipping order.

The B<analyzeDeliveries> method returns the B<HashRef>
required by the B<formatDeliveries> method.

 $hashRef = $shiporder->analyzeDeliveries;

 print $shipObj->formatDeliveries( $hashRef );


=item analyzeFailedAttempts

=item formatFailedAttempts ( HashRef )

These methods are used to analyze and format information
pertaining to FAILED deliveries of the data packet
associated with the current shipping order.

The B<analyzeFailedAttempts> method returns the B<HashRef>
required by the B<formatFailedAttempts> method.

 $hashRef = $shipObj->analyzeFailedAttempts;

 print $shipObj->formatFailedAttempts( $hashRef );


=item getList

=item count

=item stat

=item err

=item dump

These methods are defined in the parent class. 
See L<ClearCase::Vob::Info::InfoBase>.

=back

=head1 WARNING

This class supports but DOES NOT enforce syntax in the MultiSite
shipping order file. Take care to ensure that assumptions made 
herein remain accurate! Caveat Programmer.

=head1 INHERITANCE

This class inherits from the B<MultiSite::Vob::Info::InfoBase> class
which inherits from the B<ClearCase::Vob::Info::InfoBase> class.

=head1 SEE ALSO

See L<MultiSite::Vob::Info::InfoBase> and L<ClearCase::Vob::Info::InfoBase>.

=head1 AUTHOR

Chris Cobb, E<lt>chris@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 2004 by Hewlett-Packard. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
