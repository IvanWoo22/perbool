#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Getopt::Long;

use Perbool::Fastq qw(
  assert_distinct_paths open_fastq_reader open_fastq_writer read_fastq_record
);

=head1 NAME

fastq_randomsampling.pl -- Randomly sample records from a FASTQ file.

=head1 SYNOPSIS

    perl fastq_randomsampling.pl \
        --quantity 100 --seed 42 \
        --in input.fq --out sampled.fq

        Options:
            --help|-h              Brief help message
            --quantity|-q          Number of records to sample (required)
            --seed                 Random seed for reproducible sampling
            --without-replacement  Sample each input record at most once
            --in|-i                Input FASTQ path
            --out|-o               Output FASTQ path

By default, sampling is performed with replacement to preserve the historical
behavior of this script. Gzip input and output are selected by a C<.gz>
filename suffix.

=cut

Getopt::Long::GetOptions(
    'help|h'              => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s'              => \my $in_fq,
    'quantity|q=i'        => \my $quantity,
    'seed=i'              => \my $seed,
    'without-replacement' => \my $without_replacement,
    'out|o=s'             => \my $out_fq,
) or Getopt::Long::HelpMessage(1);

die "--in, --out, and --quantity are required\n"
  unless defined $in_fq && defined $out_fq && defined $quantity;
die "--quantity must be a positive integer\n" unless $quantity > 0;
assert_distinct_paths( $in_fq, $out_fq );

srand($seed) if defined $seed;

sub SAMPLE_WITHOUT_REPLACEMENT {
    my ( $total, $wanted ) = @_;
    my %selected;

    # Floyd's algorithm selects $wanted unique integers using O($wanted) memory.
    for my $upper ( $total - $wanted .. $total - 1 ) {
        my $candidate = int( rand( $upper + 1 ) );
        my $picked = exists $selected{$candidate} ? $upper : $candidate;
        $selected{$picked} = 1;
    }

    return sort { $a <=> $b } keys %selected;
}

my $count_fh = open_fastq_reader($in_fq);
my $record_count = 0;
while ( read_fastq_record( $count_fh, $record_count + 1 ) ) {
    $record_count++;
}
close $count_fh;

die "Input FASTQ contains no records\n" if $record_count == 0;
die "--quantity ($quantity) exceeds the number of input records "
  . "($record_count) when using --without-replacement\n"
  if $without_replacement && $quantity > $record_count;

my @sample_indices;
if ($without_replacement) {
    @sample_indices = SAMPLE_WITHOUT_REPLACEMENT( $record_count, $quantity );
}
else {
    @sample_indices = map { int( rand($record_count) ) } 1 .. $quantity;
}

my %positions_for;
for my $output_position ( 0 .. $#sample_indices ) {
    push @{ $positions_for{ $sample_indices[$output_position] } },
      $output_position;
}

my @sampled_records;
my $sample_fh = open_fastq_reader($in_fq);
for my $record_index ( 0 .. $record_count - 1 ) {
    my $record = read_fastq_record( $sample_fh, $record_index + 1 );
    next unless exists $positions_for{$record_index};
    for my $output_position ( @{ $positions_for{$record_index} } ) {
        $sampled_records[$output_position] = $record;
    }
}
close $sample_fh;

my $out_fh = open_fastq_writer($out_fq);
for my $output_position ( 0 .. $#sampled_records ) {
    my $record = $sampled_records[$output_position];
    my $qname  = $record->{header};
    my $plus   = $record->{separator};
    $qname =~ s/\r?\n\z//;
    my ( $read_id, @description ) = split /\s+/, $qname;
    $read_id .= ':' . ( $output_position + 1 );
    my $output_qname = join ' ', $read_id, @description;
    if ( $plus !~ /^[+]\s*\r?\n\z/ ) {
        $plus = '+' . substr( $output_qname, 1 ) . "\n";
    }
    print {$out_fh}
      "$output_qname\n$record->{sequence}$plus$record->{quality}";
}
close $out_fh;

__END__
