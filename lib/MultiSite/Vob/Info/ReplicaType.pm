# -*- Perl -*-
#
# File:  MultiSite/Vob/Info/ReplicaType.pm
# Desc:  Container for VOB Replica information
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#

package MultiSite::Vob::Info::ReplicaType;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.02';
 @ISA     = qw( ClearCase::Vob::Info::ReplicaType );

 use ClearCase::Vob::Info::ReplicaType;
#_________________________
1; # Required by require()
