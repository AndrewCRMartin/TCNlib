#!/usr/bin/env perl
# 
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl automatc_patches.t'

# Test file created outside of h2xs framework.
# Run this like so: `perl automatc_patches.t'
#   Tom Northey <zcbtfo4@acrm18>     2013/09/16 17:35:35

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Data::Dumper;

use lib ( '..' );

use pdb;

use Test::More qw( no_plan );
use Test::Deep;
BEGIN { use_ok( 'pdb::automatic_patches' ); }
use FindBin qw($RealBin);
chdir($RealBin); # So test data files can be found

#########################

# Insert your test code below, the Test::More module is used here so read
# its man page ( perldoc Test::More ) for help writing this test script.


my %arg
    = ( radius => 8,
        patch_type => 'normal',
        pdb_code => '1qok',
        pdb_file => '1qok.pdb'
    );

my $auto = automatic_patches->new(%arg);

my @summary = ();

my %summ_hash = ();

foreach my $patch ($auto->get_patches) {
    if ( ref $patch ne 'patch' ) {
        next;
    }
    else {
        $summ_hash{$patch->summary()} = 1;
    }    
}

# New file to check against. Patch lines now have <patch chain_id.resSeq>
# format (rather than <patch chain_idresSeq>)
my $exp_patch_file = 'automatic_patches_expected.out';

open(my $fh, '<', $exp_patch_file)
    or die "Cannot open file $exp_patch_file, $!\n"; 

my @exp_summary = <$fh>;

my %exp_hash = ();

foreach my $summ (@exp_summary) {
    $exp_hash{$summ} = 1;
}

cmp_deeply(\%summ_hash, \%exp_hash,
           "get_patches produces correct patch summaries");

print "Testing  BUILDARGS for when given a pdb object ...\n";

my $chain = chain->new(pdb_code => '1djs', chain_id => 'A',
                       pdb_file => '1djs.pdb');

my $ap_from_pdb = new_ok('automatic_patches', [ pdb_object => $chain,
                                                radius => 8,
                                                patch_type => 'contact' ]
                                            );
# Test patch_centres arg to get_patches
my @patches
    = $ap_from_pdb->get_patches(patch_centres => [$chain->atom_array->[212]]);

is(scalar @patches, 1,
   "get_patches called w/ patch_centres arg returns correct num of patches ...");
is($patches[0]->central_atom->resSeq(), '173',
   "... and patch has correct central_atom");

# Test production of patches from multiple chains
my @chains = getChainArray();

my $multiChainAP
    = automatic_patches->new(pdb_object => [@chains[0..1]], radius => 8,
                             patch_type => 'contact');

ok(testForMultiChainPatches($multiChainAP), "multi-chain input works ok");

# Test must be run on automatic_patches initialized with 1djs chains A and B
sub testForMultiChainPatches {
    my $autoPatches = shift;

    my $expSumm
        = "<patch A.281> A:280 A:281 A:282 B:6 B:7\n";
    
    foreach my $patch ($multiChainAP->get_patches()) {
        
        if ($patch->central_atom()->resSeq()  == 281
            && $patch->central_atom->chainID() eq 'A'
            && $patch->summary() eq $expSumm) {
            return 1;
        }
    }
    return 0;
}
    
sub getChainArray {
    my $pdb = pdb->new(pdb_code => '1djs', pdb_file => '1djs.pdb');
    my @chains = $pdb->create_chains();

    return @chains;
}
