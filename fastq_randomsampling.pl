#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use IO::Zlib;
use Getopt::Long;

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
die "--in and --out must refer to different files\n" if $in_fq eq $out_fq;

srand($seed) if defined $seed;

sub OPEN_INPUT {
    my $path = shift;
    if ( $path =~ /[.]gz\z/ ) {
        my $fh = IO::Zlib->new( $path, 'rb' )
          or die "Cannot open $path: $!\n";
        return $fh;
    }
    open my $fh, '<', $path;
    return $fh;
}

sub OPEN_OUTPUT {
    my $path = shift;
    if ( $path =~ /[.]gz\z/ ) {
        my $fh = IO::Zlib->new( $path, 'wb9' )
          or die "Cannot open $path: $!\n";
        return $fh;
    }
    open my $fh, '>', $path;
    return $fh;
}

sub READ_RECORD {
    my ( $fh, $record_number ) = @_;
    my $qname = <$fh>;
    return unless defined $qname;

    my $sequence = <$fh>;
    my $plus     = <$fh>;
    my $quality  = <$fh>;
    die "Truncated FASTQ record $record_number\n"
      unless defined $sequence && defined $plus && defined $quality;
    die "Invalid FASTQ header in record $record_number: $qname"
      unless $qname =~ /^@/;
    die "Invalid FASTQ separator in record $record_number: $plus"
      unless $plus =~ /^[+]/;

    my $sequence_value = $sequence;
    my $quality_value  = $quality;
    $sequence_value =~ s/\r?\n\z//;
    $quality_value  =~ s/\r?\n\z//;
    die "Sequence and quality lengths differ in FASTQ record $record_number\n"
      unless length($sequence_value) == length($quality_value);

    return [ $qname, $sequence, $plus, $quality ];
}

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

my $count_fh = OPEN_INPUT($in_fq);
my $record_count = 0;
while ( READ_RECORD( $count_fh, $record_count + 1 ) ) {
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
my $sample_fh = OPEN_INPUT($in_fq);
for my $record_index ( 0 .. $record_count - 1 ) {
    my $record = READ_RECORD( $sample_fh, $record_index + 1 );
    next unless exists $positions_for{$record_index};
    for my $output_position ( @{ $positions_for{$record_index} } ) {
        $sampled_records[$output_position] = $record;
    }
}
close $sample_fh;

my $out_fh = OPEN_OUTPUT($out_fq);
for my $output_position ( 0 .. $#sampled_records ) {
    my ( $qname, $sequence, $plus, $quality ) =
      @{ $sampled_records[$output_position] };
    $qname =~ s/\r?\n\z//;
    my ( $read_id, @description ) = split /\s+/, $qname;
    $read_id .= ':' . ( $output_position + 1 );
    my $output_qname = join ' ', $read_id, @description;
    if ( $plus !~ /^[+]\s*\r?\n\z/ ) {
        $plus = '+' . substr( $output_qname, 1 ) . "\n";
    }
    print {$out_fh} "$output_qname\n$sequence$plus$quality";
}
close $out_fh;

__END__
