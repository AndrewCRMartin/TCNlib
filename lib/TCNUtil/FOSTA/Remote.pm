package FOSTA::Remote;
use Moose;
use Carp;
use TCNUtil::WEB::FOSTA;
use UNIPROT;
use TCNUtil::sequence;

with 'FOSTA::FEPFinder';

$::FEPLimit = 10;

sub getReliableFEPSequencesFromSwissProtID {
    my $self        = shift;
    my $swissProtID = shift;
    my ($errorCode, @fepIDs) = WEB::FOSTA::GetFOSTA($swissProtID);
    croak "Error code $errorCode returned by WEB::FOSTA::GetFOSTA!"
        if $errorCode;

    my @fepFASTAs;
    my $count = 0;
    foreach my $fepID (@fepIDs)
    {
        print "INFO: Getting sequence for $fepID\n";
        push @fepFASTAs, UNIPROT::GetFASTA($fepID, -remote => 1);
        last if($::FEPLimit && (++$count >= $::FEPLimit));
    }
#        @fepFASTAs = map {UNIPROT::GetFASTA($_, -remote => 1)} @fepIDs;

    return map {sequence->new($_)} @fepFASTAs;
}

1;
