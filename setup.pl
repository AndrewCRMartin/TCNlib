#!/usr/bin/perl -s
use strict;
use warnings;

$::perl = 'perl' if(!defined($::perl));

#print "Initialising sub-modules ...\n";
#system("git submodule update --init --recursive");

print "Getting external packages ...\n";
system("./getexternalpackages");

print "Getting perl dependencies ...\n";
system("yes | $::perl ./getperldeps.pl");

print "Copying TCNPerlVars.defaults to TCNPerlVars.pm ...\n";
system("cp lib/TCNPerlVars.defaults lib/TCNPerlVars.pm");
