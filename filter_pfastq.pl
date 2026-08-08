#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Getopt::Long;

use Perbool::Fastq qw(
  assert_distinct_paths open_fastq_reader open_fastq_writer paired_fastq_id
  read_fastq_record sequence_text write_fastq_record
);

=head1 NAME

filter_pfastq.pl -- Filter reads with a specific length from paired FastQ files.

=head1 SYNOPSIS

    perl filter_pfastq.pl --max 30 --min 20 -1 input1.fq -2 input2.fq -o output --gzip
        Options:
            --help\-h Brief help message
            --max\-M  The maximum length of the fragment
            --min\-m  The minimum length of the fragment
            -1   R1 FastQ file with path
            -2   R2 FastQ file with path
            --out\-o  FastQ files prefix with path
            --gzip  Use gzip for output. Default: False

=cut

Getopt::Long::Configure('no_ignore_case');
Getopt::Long::GetOptions(
    'help|h'  => sub { Getopt::Long::HelpMessage(0) },
    '1=s'     => \my $in_fq1,
    '2=s'     => \my $in_fq2,
    'max|M=i' => \my $max,
    'min|m=i' => \my $min,
    'out|o=s' => \my $out_fq,
    'gzip'    => \my $gzip,
) or Getopt::Long::HelpMessage(1);

die "--1, --2, and --out are required\n"
  unless defined $in_fq1 && defined $in_fq2 && defined $out_fq;
die "--1 and --2 must refer to different inputs\n" if $in_fq1 eq $in_fq2;
die "--min and --max must be non-negative\n"
  if ( defined $min && $min < 0 ) || ( defined $max && $max < 0 );
die "--min cannot be greater than --max\n"
  if defined $min && defined $max && $min > $max;

my $out_path1 = $out_fq . ( $gzip ? '_R1.fq.gz' : '_R1.fq' );
my $out_path2 = $out_fq . ( $gzip ? '_R2.fq.gz' : '_R2.fq' );
assert_distinct_paths( $in_fq1, $in_fq2 );
assert_distinct_paths( $in_fq1, $out_path1 );
assert_distinct_paths( $in_fq1, $out_path2 );
assert_distinct_paths( $in_fq2, $out_path1 );
assert_distinct_paths( $in_fq2, $out_path2 );
assert_distinct_paths( $out_path1, $out_path2 );

my $in_fh1  = open_fastq_reader($in_fq1);
my $in_fh2  = open_fastq_reader($in_fq2);
my $out_fh1 = open_fastq_writer($out_path1);
my $out_fh2 = open_fastq_writer($out_path2);

my $max_length = $max;
my $min_length = defined $min ? $min : 0;

my $record_number = 0;
while ( my $record1 = read_fastq_record( $in_fh1, $record_number + 1 ) ) {
    $record_number++;
    my $record2 = read_fastq_record( $in_fh2, $record_number );
    die "Paired FASTQ files contain different numbers of records\n"
      unless defined $record2;
    die "Paired FASTQ read IDs do not match: "
      . "$record1->{header}$record2->{header}"
      unless paired_fastq_id($record1) eq paired_fastq_id($record2);

    my $read_length1 = length( sequence_text($record1) );
    my $read_length2 = length( sequence_text($record2) );

    if (    ( $min_length <= $read_length1 )
        and ( !defined $max_length || $max_length >= $read_length1 )
        and ( $min_length <= $read_length2 )
        and ( !defined $max_length || $max_length >= $read_length2 ) )
    {
        write_fastq_record( $out_fh1, $record1 );
        write_fastq_record( $out_fh2, $record2 );
    }
}

die "Paired FASTQ files contain different numbers of records\n"
  if defined read_fastq_record( $in_fh2, $record_number + 1 );

close $in_fh1 unless $in_fq1 eq '-';
close $in_fh2 unless $in_fq2 eq '-';
close $out_fh1;
close $out_fh2;

__END__
