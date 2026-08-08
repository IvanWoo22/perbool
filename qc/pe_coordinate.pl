#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Perbool::Fastq qw(
  assert_distinct_paths open_fastq_reader paired_fastq_id read_fastq_record
  sequence_text
);

die "Usage: perl qc/pe_coordinate.pl R1.fq[.gz] R2.fq[.gz]\n"
  unless @ARGV == 2;
my ( $r1_path, $r2_path ) = @ARGV;
die "R1 and R2 must refer to different inputs\n" if $r1_path eq $r2_path;
assert_distinct_paths( $r1_path, $r2_path );

sub REV_COMP {
    my $sequence = reverse shift;
    $sequence =~ tr/AGTCagtc/TCAGtcag/;
    return $sequence;
}

my $r1_fh = open_fastq_reader($r1_path);
my $r2_fh = open_fastq_reader($r2_path);
my $record_number = 0;

while ( my $record1 = read_fastq_record( $r1_fh, $record_number + 1 ) ) {
    $record_number++;
    my $record2 = read_fastq_record( $r2_fh, $record_number );
    die "Paired FASTQ files contain different numbers of records\n"
      unless defined $record2;
    die "Paired FASTQ read IDs do not match: "
      . "$record1->{header}$record2->{header}"
      unless paired_fastq_id($record1) eq paired_fastq_id($record2);

    my $sequence1 = sequence_text($record1);
    my $sequence2 = sequence_text($record2);
    my $reverse2  = REV_COMP($sequence2);
    print "$sequence1\n"
      if $sequence1 eq $sequence2 || $sequence1 eq $reverse2;
}

die "Paired FASTQ files contain different numbers of records\n"
  if defined read_fastq_record( $r2_fh, $record_number + 1 );

close $r1_fh unless $r1_path eq '-';
close $r2_fh unless $r2_path eq '-';

__END__
