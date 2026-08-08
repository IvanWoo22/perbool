#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Getopt::Long;

use Perbool::Fastq qw(
  assert_distinct_paths open_fastq_reader open_fastq_writer quality_text
  read_fastq_record sequence_text
);

=head1 NAME

fastqKmer.pl -- Split FASTQ reads into fixed-length windows.

=head1 SYNOPSIS

    perl fastqKmer.pl --kmer 20 --step 5 --in input.fq --out output.fq

        Options:
            --help|-h    Brief help message
            --kmer|-K   Window length (required)
            --step|-S   Distance between window starts (default: 1)
            --prefix    Optional suffix added before the window index
            --in|-i     Input FASTQ path
            --out|-o    Output FASTQ path

=cut

Getopt::Long::GetOptions(
    'help|h'   => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s'   => \my $in_fq,
    'kmer|K=i' => \my $kmer,
    'step|S=i' => \my $step,
    'prefix=s' => \my $prefix,
    'out|o=s'  => \my $out_fq,
) or Getopt::Long::HelpMessage(1);

die "--in, --out, and --kmer are required\n"
  unless defined $in_fq && defined $out_fq && defined $kmer;
$step = 1 unless defined $step;
die "--kmer and --step must be positive integers\n"
  unless $kmer > 0 && $step > 0;
assert_distinct_paths( $in_fq, $out_fq );

sub SPLIT_STR {
    my ( $STR, $LENGTH, $STEP ) = @_;
    my $STR_LENGTH = length $STR;
    my ( @READS, $LAST_SEED );
    for ( my $SEED = 0 ; $SEED + $LENGTH <= $STR_LENGTH ; $SEED += $STEP ) {
        push @READS, substr( $STR, $SEED, $LENGTH );
        $LAST_SEED = $SEED;
    }
    my $TAIL_SEED = $STR_LENGTH - $LENGTH;
    if ( @READS && $LAST_SEED != $TAIL_SEED ) {
        push @READS, substr( $STR, $TAIL_SEED, $LENGTH );
    }
    return \@READS;
}

my $in_fh  = open_fastq_reader($in_fq);
my $out_fh = open_fastq_writer($out_fq);

if ( !defined $prefix ) {
    $prefix = "";
}
else {
    $prefix = ":" . $prefix;
}

my $record_number = 0;
while ( my $record = read_fastq_record( $in_fh, ++$record_number ) ) {
    my $qname = $record->{header};
    $qname =~ s/\r?\n\z//;
    my @qntemp   = split( /\s+/, $qname );
    my $sequence = sequence_text($record);
    my $quality  = quality_text($record);

    if ( $kmer <= length($sequence) ) {
        my $seq = SPLIT_STR( $sequence, $kmer, $step );
        my $qua = SPLIT_STR( $quality,  $kmer, $step );
        foreach my $i ( 0 .. $#{$seq} ) {
            my $new_qname = "$qntemp[0]$prefix\_$i";
            if ( $#qntemp >= 1 ) {
                $new_qname .= " " . join( " ", @qntemp[ 1 .. $#qntemp ] );
            }
            print $out_fh
              "$new_qname\n${$seq}[$i]\n+\n${$qua}[$i]\n";
        }
    }
}
close $in_fh  unless $in_fq  eq '-';
close $out_fh unless $out_fq eq '-';

__END__
