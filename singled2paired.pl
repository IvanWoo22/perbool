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

singled2paired.pl -- Create paired-end reads from the ends of longer reads.

=head1 SYNOPSIS

    perl singled2paired.pl --length 100 \
        --in long.fq --R1 reads_R1.fq --R2 reads_R2.fq

        Options:
            --help|-h     Brief help message
            --length|-l   Length of each generated end (required)
            --in|-i       Input FASTQ path
            --R1|-1       Output path for the left end
            --R2|-2       Output path for the reverse-complemented right end

=cut

Getopt::Long::GetOptions(
    'help|h'     => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s'     => \my $in_fq,
    'length|l=i' => \my $length,
    'R1|1=s'     => \my $out_fq1,
    'R2|2=s'     => \my $out_fq2,
) or Getopt::Long::HelpMessage(1);

die "--in, --length, --R1, and --R2 are required\n"
  unless defined $in_fq
  && defined $length
  && defined $out_fq1
  && defined $out_fq2;
die "--length must be a positive integer\n" unless $length > 0;
die "--R1 and --R2 must refer to different files\n"
  if $out_fq1 eq $out_fq2;
assert_distinct_paths( $in_fq,  $out_fq1 );
assert_distinct_paths( $in_fq,  $out_fq2 );
assert_distinct_paths( $out_fq1, $out_fq2 );

sub SEQ_REV_COMP {
    my $SEQ = reverse shift;
    $SEQ =~ tr/Uu/Tt/;
    return ( $SEQ =~ tr/AGCTagct/TCGAtcga/r );
}

my $in_fh   = open_fastq_reader($in_fq);
my $out_fh1 = open_fastq_writer($out_fq1);
my $out_fh2 = open_fastq_writer($out_fq2);

my $record_number = 0;
while ( my $record = read_fastq_record( $in_fh, ++$record_number ) ) {
    my $qname = $record->{header};
    $qname =~ s/\r?\n\z//;
    my @qntemp   = split( /\s+/, $qname );
    my $sequence = sequence_text($record);
    my $quality  = quality_text($record);

    if ( $length <= length($sequence) ) {
        my $seq1 = substr( $sequence, 0,        $length );
        my $seq2 = substr( $sequence, -$length, $length );
        my $qua1 = substr( $quality,  0,        $length );
        my $qua2 = substr( $quality,  -$length, $length );
        $seq2 = SEQ_REV_COMP($seq2);
        $qua2 = reverse($qua2);
        my $description =
          $#qntemp >= 1 ? ' ' . join( ' ', @qntemp[ 1 .. $#qntemp ] ) : '';
        print {$out_fh1}
          "$qntemp[0] 1$description\n$seq1\n+\n$qua1\n";
        print {$out_fh2}
          "$qntemp[0] 2$description\n$seq2\n+\n$qua2\n";
    }
}
close $in_fh  unless $in_fq eq '-';
close $out_fh1;
close $out_fh2;

__END__
