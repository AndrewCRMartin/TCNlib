#!/usr/bin/perl
# 
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl pdb.t'

# Test file created outside of h2xs framework.
# Run this like so: `perl pdb.t'
#   Tom Northey <zcbtfo4@acrm18>     2013/09/11 15:07:05

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Data::Dumper;

use lib ( '..' );
use Test::More qw( no_plan );
use Test::Deep;
use Test::Exception;
use pdb::pdbFunctions;

BEGIN { use_ok('pdb'); }

#########################

# Insert your test code below, the Test::More module is used here so read
# its man page ( perldoc Test::More ) for help writing this test script.


### Tests ######################################################################

# Atom object tests
my $ATOM_line
    = "ATOM     13  CG  LEU A 148      13.227  45.000  23.178  1.00 47.53           C";

my $atom = atom->new( ATOM_line => $ATOM_line );

isa_ok($atom, 'atom', "atom object created ok");

# HETATM

my $HETATM_line
    = "HETATM 2105  N   MSE B  67      68.539  35.469  16.161  1.60  0.00           N  \n";

my $het_atom = atom->new( ATOM_line => $HETATM_line );

is( $het_atom->is_het_atom, 1, "het atom identified" );

my $het_atom_string = "$het_atom";

is( $het_atom_string, $HETATM_line, "stringify okay for het atoms" );

# pdb object tests

my $pdb_file = '1djs.pdb';

my $pdb = pdb->new( pdb_file => $pdb_file, pdb_code => '1djs' );
isa_ok($pdb, 'pdb', "pdb object created ok");

# BUILD method gets attributes from getresol objet

cmp_deeply( [ $pdb->experimental_method(), $pdb->resolution(),
              $pdb->r_value ],
            [ 'crystal', '2.40', '0.227' ],
            "BUILD method gets attributes from getresol object okay" );


# fh builder test
is( ref $pdb->pdb_data, 'ARRAY', "fh builder okay" );

## _parse_ATOM_lines

my @ATOM_lines = $pdb->_parse_ATOM_lines;

ok( (grep /^HETATM/, @ATOM_lines),
    "HETATM lines included by _parse_ATOM_lines");

## _parse_atoms

$pdb->_parse_atoms();

is( scalar @{ $pdb->atom_array() }, 3066,
    "all ATOM and HETATM lines parsed and included in atom_array" );

# _parse_ter

my $ter_line = "TER    2725      SO4 A 407 \n";

my($serial, $chainID) = pdb::_parse_ter($ter_line);

is( $serial, '2725', "_parse_ter parses serial ok"  );
is( $chainID, 'A'  , "_parse_ter parses chainID ok" );

# pdb file containing multiple models - for the moment, exception needs
# to be thrown (untill I write in capacity to deal with multi-model pdbs)

my $multimodel_file = '/acrm/data/pdb/pdb2q1z.ent';

dies_ok(
    sub { pdb->new( pdb_file => $multimodel_file, pdb_code => '2q1z' )
      },  "Croak  if pdb is multimodel" );

# atom_, resid_ and pdbresid_index

ok($pdb->atom_index(), "atom_index ok");
ok($pdb->resid_index, "resid_index ok" );

ok($pdb->pdbresid_index, "pdbresid_index ok");

# test out get_sequence
 
my $exp_seq_string
    = "TLEPEGAPYWTNTEKXEKRLHAVPAANTVKFRCPAGGNPXPTXRWLKNGKEFKQEHRIGGYKVRNQHWSLIX"
    . "ESVVPSDKGNYTCVVENEYGSINHTYHLDVVERSPHRPILQAGLPANASTVVGGDVEFVCKVYSDAQPHIQW"
    . "IKHVEKPYLKVLKAAGVNTTDKEIEVLYIRNVTFEDAGEYTCLAGNSIGISFHSAWLTVLPA";

my @seq = $pdb->get_sequence( chain_id => 'A', return_type => 1, );
my $seq_string = join ( '', @seq );

is($seq_string, $exp_seq_string, 'get_sequence works okay');

# test getFASTAStr
my $expFASTAStr = ">1djsA\n" . $exp_seq_string . "\n";

is($pdb->getFASTAStr(chain_id => "A"), $expFASTAStr, "getFASTAStr works oK");

# map_resSeq2chainSeq

ok($pdb->map_resSeq2chainSeq('A'), "mapresSeq2chainSeq ok");

# test out chain solvent determination

my $multi_term_pdb_code = '2we8';
my $multi_term_file = '/acrm/data/pdb/pdb2we8.ent';

my $mterm_pdb = pdb->new( pdb_code => $multi_term_pdb_code,
                          pdb_file => $multi_term_file, );

$mterm_pdb->atom_array();

# is_terminal atom attribute

my $term_atom  = $pdb->resid_index->{"A.362"}->{CB};
my $term_atom2 = $pdb->resid_index->{"B.140"}->{OD2};

cmp_deeply( [ $term_atom->is_terminal, $term_atom2->is_terminal ], [ 1, 1 ],
            "terminal atom labelled");

my $term_string = $term_atom->stringify_ter();
my $exp_string  = "TER    1628  CB  ALA A 362 \n\n";
is($term_string, $exp_string, "stringify_ter returns TER string ok" );

# chain object

my $chain_id = 'A';
my $chain
    = chain->new( pdb_file => $pdb_file,
                  pdb_code => '1djs',
                  chain_id => 'A' );

isa_ok($chain, 'chain', "chain object created ok");

## are around modifiers for _parse_ATOM_lines working?

$chain->_parse_atoms();

# around modifier for get_sequence and map_resSeq2chainSeq working okay?

ok($chain->get_sequence(return_type => 1),
   "get_sequence works ok for chain");

ok($chain->map_resSeq2chainSeq(), "map_resSeq2chainSeq ok for chain");
ok($chain->map_chainSeq2resSeq(), "map_chainSeq2resSeq ok for chain");

# Chain length working?

is($chain->chain_length, 206, "chain length determined ok");


# get accession codes using pdbsws?

#is( $chain->accession_codes()->[0], 'P21802',
#    "Accession codes from pdbsws" );

# reading ASAs and radii from xmas2pdb object

my $xmas2pdb_file = 'xmas2pdb';
my $xmas_file     = '1djs.xmas';
my $radii_file    = 'radii.dat';
my $form          = 'multimer';

my %arg = (xmas2pdb_file => $xmas2pdb_file,
           xmas_file     => $xmas_file,
           radii_file    => $radii_file,
           form          => $form,
       );

my $x2p = xmas2pdb->new(%arg);

my $test_atom = $pdb->atom_array->[1];

$pdb->read_ASA($x2p);

ok($test_atom->radius(), "Radius read from xmas2pdb object" );
ok($test_atom->ASAc(), "Multimer ASA read from xmas2pdb object" );

$arg{form} = 'monomer';

my $mono_x2p = xmas2pdb->new(%arg);

$pdb->read_ASA($mono_x2p);

ok($test_atom->ASAm(), "Monomer ASA read from xmas2pdb object" );

# test highestASA method

my $resid = 'A.147';

is($pdb->highestASA($resid)->ASAc(), '69.01',
   "highestASA returns highest ASA atom");

# patch_centres

my %pc_arg = ( ASA_threshold => 25 );

my ($errors, $patch_centres) = $pdb->patch_centres( %pc_arg );

($errors, $patch_centres) = $chain->patch_centres( %pc_arg);

ok( @{ $errors }, "Errors returned if ASAm has not been set for chain" );

$chain->read_ASA($mono_x2p);

ok( $chain->patch_centres( %pc_arg),
    "patch_centres modified for chain object" );

# test multi_resName_resid

my $bad_chain = chain->new( pdb_code => '3u5e',
                            chain_id => 'O',
                            pdb_file => '3u5e.pdb'
                        );

$bad_chain->atom_array();

is( scalar keys %{ $bad_chain->multi_resName_resids() }, '136',
    "multi_resName_resid captures resids with multi resName-atoms" );

# solvent_cleanup flag

my $solv_pdb_file = '3o0r.pdb';

my $solv_chain = chain->new( pdb_code => '3o0r',
                             pdb_file => $solv_pdb_file,
                             chain_id => 'C',
                             solvent_cleanup => 1,
                         );

is($solv_chain->atom_array->[-1]->serial(), 8063,
   "cleanup_solvent flag works ok" );

# Creating chain object from a pdb object
my @chains = $pdb->create_chains();

ok(testChains($pdb, @chains), "Create chains works okay");

# test isAbVariable
my $abComplex = pdb->new(pdb_code => '1afv',
                         pdb_file => '1afv.pdb');

# test compareResSeqs
my $rsA = "52";
my $rsB = "52A";

is(pdb::pdbFunctions::compare_resSeqs($rsA, $rsB), -1, "compareResSeqs works okay");

# test sorted_atom_arrays
ok(testSortedAtomArray($pdb->sorted_atom_arrays()), "sorted_atoms works okay");

# Test isAbVariable
@chains = $abComplex->create_chains('A', 'L', 'H');
my %return = map { $_->chain_id() => $_->isAbVariable()  } @chains;

cmp_deeply(\%return, ExpChains(),
           "isAbVariable works okay");

# Test seq_range_atoms
testSeqRangeAtoms();

# test $atom->contacting()
testAtomContacting();

# test chain->determineEpitope
ok(testDetermineEpitope(@chains),
   "determineEpitope identifies epitope residues ok");

# Test getAbPairs()
testGetAbPairs($abComplex);

# Test isInContact
testIsInContact($abComplex);

ok($chains[0]->rotate2PCAs(qw(A.95 A.96 A.97 A.98 A.105 A.103)),
   "rotate2PCAs works ok");

ok($chains[0]->rotate2Face(), "rotate2face works ok");

# Test pdb->store()
my $storedObjFname = "testStoredPDB.obj"; 
ok($chains[0]->storeInFile($storedObjFname) && -e $storedObjFname,
   "store works okay");
unlink($storedObjFname);

# Test processAlnStr
my $testAlnStr = getTestAlnStr();
my $testAlignedChain = getTestAlignedChain();

$testAlignedChain->processAlnStr(alnStr => $testAlnStr,
                                 includeMissing => 1);
is($testAlignedChain->resid_index->{"P.168"}->{CA}->alnSeq(), 298,
   "processAlnStr ok");

# Test missing_residues
my $expHash = { P => { 164 => "GLU", 165 => "LEU", 166 => "ARG",
                       167 => "ASP", 179 => "LEU", 180 => "ASP",
                       181 => "ILE", 182 => "VAL" } };

cmp_deeply($testAlignedChain->missing_residues(), $expHash,
           "missing_residues ok");

# Test remark_hash
like(${$pdb->remark_hash()->{290}->[0]}, qr/REMARK 290\s+/,
   "remark_hash ok");

# Test _build_summary
my ($testPatch, $expSummary) = getTestSummaryPatch();

is($testPatch->summary(), $expSummary, "_build_summary works ok");

# Test parseSummaryLine
my $testSummaryLine
    = "<patch G.409> G:335 G:397 G:398 G:407 G:408 G:409 G:410\n";
my @expResids = qw(G.409 G.335 G.397 G.398 G.407 G.408 G.410);

cmp_deeply([patch::parseSummaryLine($testSummaryLine)], \@expResids,
           "parseSummaryLine works okay");

# Test building patch from summary and parent pdb
$testSummaryLine = "<patch A.147> A:147 A:148 A:149 A:150 A:151";
my $testPatchFomSummary = patch->new(parent_pdb => $pdb,
                                     summary => $testSummaryLine);

my $expCentralAtomStr = "ATOM      2  CA  THR A 147      17.142  46.945  24.205  1.00 49.31           C\n";
my $retCentralAtomStr = $testPatchFomSummary->central_atom->stringify();
is($testPatchFomSummary->central_atom(), $retCentralAtomStr,
   "patch built from summary: central atom ok ");

is($testPatchFomSummary->summary(), $testSummaryLine,
   "patch built from summary: input summary returned after build");

### Subroutines ################################################################

sub getTestSummaryPatch {

    my @atomArray = ();
    
    foreach my $chain (qw(B A)) {
        foreach my $resSeq (qw(2 3 1)) {
            my $atom = atom->new(chainID => $chain, resSeq => $resSeq,
                                 name => 'CA');
            push(@atomArray, $atom);
        }
    }
    
    my $patch = patch->new(pdb_code => '1abc',
                           central_atom => $atomArray[0],
                           atom_array => \@atomArray);
    
    my $expSummary = "<patch B.2> A:1 A:2 A:3 B:1 B:2 B:3\n";

    return($patch, $expSummary);
}


sub getTestAlignedChain {
    my $pdbFile = "4hpy.pdb";
    my $chain = chain->new(chain_id => "P",
                           pdb_file => $pdbFile,
                           pdb_code => "4hpy");
    return $chain;
}


sub getTestAlnStr {    
    my $alnStr
        = "--------------------------------------------------------------------"
        . "--------------------------------------------------------------------"
        . "--------------------------------------------------------------------"
        . "--------------------------------------------------------------------"
        . "---------------------ELRDKKQKV--------------------HALFYKLDIV--------"
        . "--------------------------------------------------------------------"
        . "--------------------------------------------------------------------"
        . "---";

    return $alnStr;
}

    
sub testIsInContact {
    my $pdb = shift;

    # Get chains
    my($A, $L, $H, $B, $M, $K) = $pdb->create_chains(qw(A L H B M K));

    is($A->isInContact([$L, $H]), 1, "isInContacts finds contact ok");
    is($B->isInContact([$L, $H]), 0, "isInContacts finds no contact ok");

    my @allAtoms = (@{$L->atom_array()}, @{$H->atom_array()});
    
    is($A->isInContact(\@allAtoms), 1,
       "isInContacts finds contact ok with atom array");
    is($B->isInContact(\@allAtoms), 0,
       "isInContacts finds no contact ok with atom array");
    
}


sub testGetAbPairs {
    my $pdb = shift;

    my($combAref, $unpairedAref, $scFvAref) = $pdb->getAbPairs();

    # Unpaired and scFv array should be empty
    return 0 if @{$unpairedAref} || @{$scFvAref};

    my @expCombs = ("HL", "KM");

    my @retCombs = ();
    
    foreach my $comb (@{$combAref}) {
        push(@retCombs, $comb->[0]->chain_id() . $comb->[1]->chain_id());
    }

    cmp_bag(\@expCombs, \@retCombs, "getAbPairs works ok");
}


sub testDetermineEpitope {
    my($antigen, $light, $heavy) = @_;

    clearEpitopeFlag($antigen);
    numberAbChains($light, $heavy);

    # This will label antigen epitope atoms via flag $atom->is_epitope()
    $antigen->determineEpitope([$light, $heavy], 4, 4);
    
    my @epitopeResSeqs = coreEpitope();

    return checkEpitopeLabels($antigen, @epitopeResSeqs) ? 1 : 0;
}

sub checkEpitopeLabels {
    my($antigen, @epitopeResSeqs) = @_;

    my %epitopeResSeqs = map { $_ => 1 } @epitopeResSeqs;
    
    foreach my $atom (@{$antigen->atom_array()}){
        if (exists $epitopeResSeqs{$atom->resSeq()}){
            # Epitope atoms must be labelled is_epitope
            if (! $atom->is_epitope()){
                print "Epitope atom not labelled as epitope!\n$atom";
                return 0;
            }
            
        }
        else {
            # Non epitope atoms must not be labelled is_epitope
            if ($atom->is_epitope()) {
                print "Non-epitope atom labelled as epitope!\n$atom";
                return 0;
            }
            
        }
    }
    return 1;
}

sub coreEpitope {
    return (qw(81 74 100 82 78 85 83 76 102 79 75));
}

sub clearEpitopeFlag {
    my $antigen = shift;

    foreach my $atom (@{$antigen->atom_array()}) {
        $atom->is_epitope(0);
    }
}

sub numberAbChains {
    my @abChains = @_;

    foreach my $abChain (@abChains) {
        $abChain->kabatSequence();
    }
}

sub testAtomContacting{
    my $atomA = atom->new(x => 1, y => 2, z => 3);
    my $atomB = atom->new(x => 1, y => 2.5, z => 3);

    is($atomA->contacting($atomB, 4), 1, "contacting atoms detected okay");
}

sub testSeqRangeAtoms {

    my $method = "test_seq_range_atoms";
    
    my $chain = chain->new(pdb_code => "1afv",
                           pdb_file => "1afv.pdb",
                           chain_id => "A");

    my @range = (0, 10);

    my @atoms = $chain->seq_range_atoms(@range);
    
    is($atoms[0]->resSeq(), 1, "$method: range start ok");
    is($atoms[-1]->resSeq(), 11, "$method: range end ok");
    is(scalar @atoms, 84, "$method: got full range");

    @atoms = $chain->seq_range_atoms(120, -1);
    is($atoms[-1]->resSeq(), 151, "$method: -1 range end works ok");
}

sub testSortedAtomArray {
    my $atomsARef = shift;

    foreach my $atomARef (@{$atomsARef}) {
        my $resSeq = "";
        foreach my $atom (@{$atomARef}) {

            # Check object is an atom
            return 0 if ref $atom ne "atom";
            
            if (! $resSeq) {
                # Assign first resSeq 
                $resSeq = $atom->resSeq();
            }
            # Check if resSeqs match
            return 0 if $atom->resSeq() ne $resSeq;
        }
    }
    return 1;
}

sub ExpChains {
    return {A =>  0,
            L => 'Light',
            H => 'Heavy',};
}

sub testChains {
    my $pdb = shift;
    my @chains = @_;

   my $chainsAtomCount = 0;
    
    # Does each chain only have atoms with the correct chain id?
    foreach my $chain (@chains) {
        return 0 if ! testAtoms($chain);
        $chainsAtomCount += scalar @{$chain->atom_array()};
    }

    # Have all atoms from the original pdb been assigned?
    my $pdbAtomCount = scalar @{$pdb->atom_array()};

    return 0 if $chainsAtomCount ne $pdbAtomCount;
    
    return 1;
}


sub testAtoms {
    my $chain = shift;

    foreach my $atom (@{$chain->atom_array()}) {
        return 0 if $chain->chain_id() ne $atom->chainID();
    }
    return 1;
}
