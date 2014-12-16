#!/usr/bin/perl -w
# calc_patch_blast_scorecons_new.pl --- new script to calc patch scorecons from PSIBLAST alignment
# Author: Tom Northey <zcbtfo4@acrm18>
# Created: 21 Jan 2014
# Version: 0.01

use warnings;
use strict;
use Carp;

use Getopt::Long;
use pdb::pdb;
use IO::CaptureOutput qw( qxx );

use lib '/home/bsm/anya/perllib'; #sets dir where Perl_paths.pm is
use Perl_paths;

my $USAGE = <<EOF;
$0
 USAGE: -pdb_dir <DIR> -patch_dir <DIR> -aln_dir <DIR> -log_dir <DIR>
        -out_dir <DIR>
EOF

my $pdb_dir;
my $patch_dir;
my $aln_dir;
my $log_dir;
my $out_dir;

GetOptions(
    'pdb_dir=s' =>  \$pdb_dir,
    'patch_dir=s' => \$patch_dir,
    'aln_dir=s' => \$aln_dir,
    'log_dir=s' => \$log_dir,
    'out_dir=s' => \$out_dir,
);

croak $USAGE
    if ! ($pdb_dir && $patch_dir && $aln_dir && $log_dir && $out_dir);

opendir(my $PATCHES_DH, $patch_dir)
    or die "Cannot open patches dir $patch_dir";

my $log_fname = "$log_dir/calc_patch_blast_scorecons_new.log";

open(my $LOG, '>', $log_fname)
    or die "Cannot open log file '$log_fname', $!\n";

while ( my $patches_fname = readdir($PATCHES_DH) ) {

    my $patches_fpath = "$patch_dir/$patches_fname"; 
    
    # Skip '.' and '..'
    next if $patches_fname =~ m{\A \.+ \z}xms;

    print {$LOG} "Processing patches file '$patches_fname ...";
    
    my $pdb_id   = substr( $patches_fname, 0, 5);
    my $pdb_code = substr( $pdb_id, 0, 4);
    my $chain_id = substr( $pdb_id, 4, 1);

    next unless $pdb_id eq '1fe8A';
    
    my $pdb_fname = "$pdb_dir/" . uc ( $pdb_code . "_$chain_id" ) . '.pdb';
    croak "Could not find pdb file $pdb_fname" if ! -e $pdb_fname;

    # Create file handles
    
    open(my $PATCH, '<', $patches_fpath)
        or die "Cannot open patches file '$patches_fpath', $!";

    my $out_fname = "$out_dir/$pdb_id.patch.scorecons";
    
    open(my $OUT, '>', $out_fname)
        or die "Cannot open out file '$out_fname', $!";

    # Create chain object
    
    my $chain = chain->new( pdb_code => $pdb_code,
                            chain_id => $chain_id,
                            pdb_file => $pdb_fname,
                        );

    # Get mappings
    
    my %map_resSeq2chainSeq = $chain->map_resSeq2chainSeq();

    my $alignment_fname = "$aln_dir/$pdb_id";

    croak "No alignment file found for $pdb_id in dir $aln_dir! Looked for"
        . " file '$alignment_fname'" if ! -e $alignment_fname;
     
    my $aligned_seq_str
        = get_aligned_pdb_sequence($alignment_fname, $pdb_id);

    my $chain_seq_str = join('', $chain->get_sequence(return_type => 1));
    
    my %map_chainSeq2msa  = map_chainSeq2msa($aligned_seq_str, $chain_seq_str);

    my @scorecons_output  = run_scorecons($alignment_fname);
    
    my %map_msa2scorecons = map_msa2scorecons(@scorecons_output);

    # Combine mapping to create resSeq to scorecons hash

#=prints for error checking

    print "\n\nmap_resSeq2chainSeq\n\n";
    
    print "resSeq $_, chainSeq $map_resSeq2chainSeq{$_}\n" foreach sort { $a <=> $b }keys %map_resSeq2chainSeq;

    print "\n\nmap_chainSeq2msa\n\n";
    
    print "chainSeq $_, msa $map_chainSeq2msa{$_}\n" foreach sort { $a <=> $b }keys %map_chainSeq2msa;

    print "\n\nmap_msa2scorecons\n\n";
    
    print "msa $_, scorecons $map_msa2scorecons{$_}\n" foreach sort { $a <=> $b }keys %map_msa2scorecons;

#=cut
    
    my %map_resSeq2scorecons
        = map_resSeq2scorecons( \%map_resSeq2chainSeq, \%map_chainSeq2msa,
                                \%map_msa2scorecons ); 

    print {$LOG} " Mapping successful ...\n";
    
    # Apply mapping to patches from patch file
    
    while ( my $patch_string = <$PATCH> ) {
        print "$pdb_id ";
        my $patch_score = score_patch($patch_string, \%map_resSeq2scorecons);

        my ($patch_id) = $patch_string =~ m{ \A(<.*?>) }xms;

        my $score_line = "$patch_id $patch_score\n";

        # Write line to output .scorecons file
        print {$OUT} $score_line;
    }
    print {$LOG} "finished\n";

    close $PATCH;
    close $OUT;
}

print "$0 finished\n";

close $LOG;

## SUBROUTINES

sub score_patch {
    my($patch_string, $map_resSeq2scorecons) = @_;
    
    my @resSeqs = $patch_string =~ m{ :(\w+) }gxms;
    
    my $resSeq_count = 0;
    my $scorecons_total = 0;

    foreach my $resSeq (@resSeqs) {
    
        ++$resSeq_count;

        if ( ! exists $map_resSeq2scorecons->{$resSeq} ) {
            print "no resSeq2scorecons mapping for resSeq $resSeq\n";
        }
        
        $scorecons_total += $map_resSeq2scorecons->{$resSeq};
    }
    
    my $score_cons_avg = $scorecons_total / $resSeq_count;

    return $score_cons_avg;
}

sub map_resSeq2scorecons {
    my($map_resSeq2chainSeq, $map_chainSeq2msa, $map_msa2scorecons) = @_;

    my %return_hash = ();
    
    foreach my $resSeq (keys %{ $map_resSeq2chainSeq } ) {
        my $chainSeq = $map_resSeq2chainSeq->{$resSeq};

        exists $map_chainSeq2msa->{$chainSeq}
            or croak "No mapping exists for chainSeq $chainSeq to msa";

        my $msa_pos = $map_chainSeq2msa->{$chainSeq};

        # Assign score 0 to residues that were not input into the blast search
        # and muscle alingment (i.e. hetero residues)
        if ($msa_pos eq 'NULL') {
            $return_hash{$resSeq} = 0;
            next;
        }

        exists $map_msa2scorecons->{$msa_pos}
            or croak "No mapping exists for msa pos $msa_pos to scorecons";

        my $scorecons = $map_msa2scorecons->{$msa_pos};

        $return_hash{$resSeq} = $scorecons;
    }
    return %return_hash;
}
    

# Takes scorecons output and returns a hash mapping msa alignment to conserv.
# scores
sub map_msa2scorecons {
    my @scorecons_output = @_;

    my $msa_pos = 0;
    my %return_hash = ();
    
    foreach my $line (@scorecons_output) {
        chomp $line;
        $msa_pos++;

        my($score, $char, $column) = split(/\s+/, $line);
        $return_hash{$msa_pos} = $score;
    }

    return %return_hash;
}
    
# Runs scorecons process and returns output
sub run_scorecons {
    my $msa_fname = shift;

    #my $out_file = "$msa_fname.blast.scorecons";
    my $cmd = "$Perl_paths::scoreconsExe $msa_fname $Perl_paths::valdar01_params";

    my $stdout;
    my $stderr;
    my $success;
    
    ($stdout, $stderr, $success) = qxx($cmd);

    if (! $success) {
        print {$LOG} "$stderr\n";
        croak "run_scorecons failed; see log for error.\n"
            . "cmd run by run_scorecons: $cmd\n";
    }
    
    my @output = split( /(?<=\n)/, $stdout);
    
    croak "run_scorecons produced no output given cmd:\n$cmd"
        if ! @output;

    return @output;
}

sub map_chainSeq2msa {
    my $alignment_str = shift
        or die "map_chainSeq2msa must be passed an alignment string";
    my $chain_seq_str = shift
        or die "map_chainSeq2msa must be passed a chain sequence string";
    
    my %return_map = ();
    my $sequence_count = 0;

    # Loop through alignment string
    for my $i ( 0 .. length ($alignment_str) - 1 ) {
        # If substring is a residue
        if ( substr( $alignment_str, $i, 1 ) ne '-' ){

            my $aln_res = substr($alignment_str, $i, 1);
            my $seq_res = substr($chain_seq_str, $sequence_count, 1);

            # Ensure that chain and alignment residues match
            until ($aln_res eq $seq_res) {
                
                # Skip ahead in chain_seq_str
                ++$sequence_count; 
                print "DEBUG: chain seq $sequence_count: "
                    . "msa and aln residues do not match "
                    . "$aln_res $seq_res\n";

                $seq_res = substr($chain_seq_str, $sequence_count, 1);
                
                # Assign 'NULL' to map hash for this position in chainSeq
                print "DEBUG: ", substr($alignment_str, $i, 1);
                print " seq_count: $sequence_count\n";
                $return_map{$sequence_count} = 'NULL';
                print "$sequence_count: " . $return_map{$sequence_count}
                    . "\n";
            }
            
            ++$sequence_count;
            print "DEBUG: ", substr($alignment_str, $i, 1);
            print " seq_count: $sequence_count\n";
            $return_map{$sequence_count} = $i;
            print "$sequence_count: " . $return_map{$sequence_count}
                . "\n";
        }        
    }
    return %return_map;
}
    

sub get_aligned_pdb_sequence {
    my $alignment_fname = shift;
    my $seq_header_id   = shift;
    
    open(my $ALN_FH, '<', $alignment_fname)
        or die "Cannot open alignment file, '$alignment_fname', $!";

    my $in_seq = 0;

    my @seq_lines = ();
    
    while (my $line = <$ALN_FH>) { 
        if ( $line =~ m{ \A > $seq_header_id  }xms ){
            $in_seq = 1;
            next;
        }
        
        if ($in_seq) {
            # Reached next FASTA header, end of sequence
            if ( substr( $line, 0, 1) eq '>' ) {
                last;
            }
            else {
                chomp $line;
                push( @seq_lines, $line);
            }
        }
    }

    croak "No sequence lines parsed from alignment file"
        if ! @seq_lines;
   
    my $seq_str = join('', @seq_lines);

    return $seq_str;   
}
    

__END__

=head1 NAME

calc_patch_blast_scorecons_new.pl - Describe the usage of script briefly

=head1 SYNOPSIS

calc_patch_blast_scorecons_new.pl [options] args

      -opt --long      Option description

=head1 DESCRIPTION

Stub documentation for calc_patch_blast_scorecons_new.pl, 

=head1 AUTHOR

Tom Northey, E<lt>zcbtfo4@acrm18E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Tom Northey

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 BUGS

None reported... yet.

=cut