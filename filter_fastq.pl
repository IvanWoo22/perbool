#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Getopt::Long;

use Perbool::Fastq qw(
  assert_distinct_paths open_fastq_reader open_fastq_writer
  read_fastq_record sequence_text write_fastq_record
);

=head1 NAME

filter_fastq.pl -- Filter reads with a specific length from FastQ files.

=head1 SYNOPSIS

    perl filter_fastq.pl --max 30 --min 20 -i input.fq -o output.fq
        Options:
            --help\-h Brief help message
            --max\-M  The maximum length of the fragment
            --min\-m  The minimum length of the fragment
            --in\-i   The FastQ file with path
            --out\-o  The FastQ file with path

=cut

Getopt::Long::Configure('no_ignore_case');
Getopt::Long::GetOptions(
    'help|h'  => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s'  => \my $in_fq,
    'max|M=i' => \my $max,
    'min|m=i' => \my $min,
    'out|o=s' => \my $out_fq,
) or Getopt::Long::HelpMessage(1);

die "--in and --out are required\n"
  unless defined $in_fq && defined $out_fq;
die "--min and --max must be non-negative\n"
  if ( defined $min && $min < 0 ) || ( defined $max && $max < 0 );
die "--min cannot be greater than --max\n"
  if defined $min && defined $max && $min > $max;
assert_distinct_paths( $in_fq, $out_fq );

my $in_fh  = open_fastq_reader($in_fq);
my $out_fh = open_fastq_writer($out_fq);

my $max_length = $max;
my $min_length = defined $min ? $min : 0;

my $record_number = 0;
while ( my $record = read_fastq_record( $in_fh, ++$record_number ) ) {
    my $read_length = length( sequence_text($record) );
    if (    ( $min_length <= $read_length )
        and ( !defined $max_length || $max_length >= $read_length ) )
    {
        write_fastq_record( $out_fh, $record );
    }
}
close $in_fh  unless $in_fq  eq '-';
close $out_fh unless $out_fq eq '-';

__END__
