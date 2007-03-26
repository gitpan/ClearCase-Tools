# -*- Perl -*-
#
# File:  MultiSite/Vob/Info/ReplicaList.pm
# Desc:  Information about one/some/all replicas in a VOB famlily
# Auth:  Chris Cobb
# Date:  Thu Sep 27 16:13:49 2001
# Stat:  Prototype
#

package MultiSite::Vob::Info::ReplicaList;
 use strict;

 my $PACK = __PACKAGE__;
 use vars qw( $VERSION @ISA );
 $VERSION = '0.02';
 @ISA     = qw( ClearCase::Vob::Info::ReplicaList );

 use ClearCase::Vob::Info::ReplicaList;
#_________________________
1; # Required by require()
