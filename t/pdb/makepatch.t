#!/usr/bin/env perl
# 
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl makepatch.t'

# Test file created outside of h2xs framework.
# Run this like so: `perl makepatch.t'
#   Tom Northey <zcbtfo4@acrm18>     2013/09/12 13:38:30

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use warnings;
use strict;
use Data::Dumper;

use lib ( '..' );

use Test::More qw( no_plan );
BEGIN { use_ok( 'pdb::makepatch' ); }
use FindBin qw($RealBin);
chdir($RealBin); # So test data files can be found

#########################

# Insert your test code below, the Test::More module is used here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $pdb_file       = '1djs.pdb';
my $radius         = 8;
my $patch_type     = 'contact';

my $atom_line = "ATOM     31  CD  PRO A 150      16.450  43.163  16.346  1.00 44.51           C";

my $atom = atom->new( ATOM_line => $atom_line );

my $makepatch = makepatch->new( pdb_file       => $pdb_file,
                                patch_type     => $patch_type,
                                radius         => $radius,
                                central_atom   => $atom, );


my $output = $makepatch->output;

my $patch = new_ok( 'patch' => [ central_atom => $makepatch->central_atom,
                                 pdb_data => $makepatch->output ] );

print "patch->new() okay when passed a makepatch object directly?\n";

my $dir_patch = new_ok( 'patch' => [ $makepatch ] );

# Create patches from makepatch object, using a pdb object to assign pre-existing
# atom objects, rather than creating new atom objects

my $pdbObject = pdb->new(pdb_file => $pdb_file);

$makepatch = makepatch->new( pdb_file       => $pdb_file,
                             patch_type     => $patch_type,
                             radius         => $radius,
                             central_atom   => $atom,
                             pdb_object     => $pdbObject,
                             new_atoms      => 0,
                            );

$patch = patch->new($makepatch);
is($pdbObject->atom_serial_hash->{$patch->atom_array->[0]->serial()},
   $patch->atom_array->[0], "new_atoms => 0 works ok");

#$dir_patch->run_PatchOrder;
