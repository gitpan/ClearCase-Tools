# -*- Perl -*-
#
# File:  ClearCase/View/Info/List.pm
# Desc:  Default Class for ClearCase::View::Info::<module> classes
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#

package ClearCase::View::Info::List;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.01';
 @ISA     = qw( ClearCase::Vob::Info::List );

 use ClearCase::Vob::Info::List;
#_________________________
1; # Required by require()
