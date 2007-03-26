# -*- Perl -*-
#
# File:  Makefile.PL
# Desc:  Make the makefile for the ClearCase-Tools distribution
# Date:  Sat Mar 24 11:21:09 2007
#
use inc::Module::Install;

name		'ClearCase-Tools';
abstract	'Perl tools for ClearCase administrators';
author		'Chris Cobb <nospamplease@ccobb.net>';
license 	'perl';
perl_version	'5.006';
version		'0.01';
##all_from	'lib/ClearCase.pm';
tests		't/*.t';  ### t/*/*.t t/*/*/*.t';

# When building this distribution
#no_index	directory 	=> 'eg';
build_requires	Test::More	=> 0;

# Standard modules needed
requires	strict		=> 0;
requires	warnings	=> 0;

# Additional modules needed
requires 	PTools::Date::Format	=> 0;
requires	PTools::Debug		=> 0;
requires	PTools::Loader		=> 0;
requires	PTools::Local		=> 0;
requires	PTools::Options		=> 0;
requires	PTools::Proc::Backtick	=> 0;
requires	PTools::SDF::File::Mnttab => 0;
requires	PTools::SDF::INI	=> 0;
requires	PTools::Time::Elapsed	=> 0;

WriteAll();
