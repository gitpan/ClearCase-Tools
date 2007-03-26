# -*- Perl -*-
#
# File:  MultiSite/Proc/MultiTool.pm
# Desc:  OO wrapper for Atria's "multitool" command interpreter
# Auth:  Chris Cobb <cobb@cup.cup.hp.com>
# Date:  Fri Dec 07 13:35:01 2001
# Stat:  Prototype
# Note:  For Abstract, Synopsis, Dependencies and Discussion
#        see the "ClearCase/Proc/ClearTool.pm" module.
#

package MultiSite::Proc::MultiTool;

 my $PACK = __PACKAGE__;
 use vars qw($VERSION @ISA);
 $VERSION = '0.03';
 @ISA     = qw( ClearCase::Proc::ClearTool );

 use ClearCase::Proc::ClearTool;      # include parent class

sub start
{   my($self,$prog) = @_;
  
    # All this subclass has to do is provide a new default 
    # for $prog. The parent class handles everything else.
    #
    return $self->SUPER::start( $prog || "multitool" );
}
#_________________________
1; # required by require()

__END__

=head1 NAME

MultiSite::Proc::MultiTool - OO interface to Rational's cleartool/multitool 
command interpreters.

=head1 VERSION

This document describes version 0.03, released May, 2003.

=head1 SYNOPSIS

See the B<ClearCase::Proc::ClearTool> class.

=head1 DESCRIPTION

See the B<ClearCase::Proc::ClearTool> class.

=head1 INHERITANCE

This class inherits directly from the  B<ClearCase::Proc::ClearTool> class.

=head1 SEE ALSO

See L<ClearCase::Proc::ClearTool>, L<ClearCase::Vob::Info>
and L<ClearCase::Vob::Info::InfoBase>.

=head1 AUTHOR

Chris Cobb, E<lt>chris@ccobb.netE<gt>

=head1 COPYRIGHT

Copyright (c) 2002-2003 by Hewlett-Packard. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
