package Perbool::Command::FastqSample;

use strict;
use warnings;

use Exporter qw(import);
use File::Temp qw(tempfile);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fastq qw(
  assert_distinct_paths open_fastq_reader open_fastq_writer read_fastq_record
  write_fastq_record
);
use Perbool::StagedOutput qw(commit_output_group create_output_group);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool fastq sample --in INPUT.fq[.gz] --out OUTPUT.fq[.gz]
       --quantity N [--seed N] [--without-replacement]

Sample records with replacement by default for legacy compatibility. Use
--without-replacement for unique input positions. Standard streams and gzip
files are supported; --seed makes selection reproducible.
USAGE
}

sub _sample_without_replacement {
    my ( $total, $wanted ) = @_;
    my %selected;
    for my $upper ( $total - $wanted .. $total - 1 ) {
        my $candidate = int rand( $upper + 1 );
        my $picked = exists $selected{$candidate} ? $upper : $candidate;
        $selected{$picked} = 1;
    }
    return sort { $a <=> $b } keys %selected;
}

sub run {
    my @arguments = @_;
    my ( $help, $input_path, $output_path, $quantity, $seed,
        $without_replacement );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'              => \$help,
        'in|i=s'              => \$input_path,
        'out|o=s'             => \$output_path,
        'quantity|q=i'        => \$quantity,
        'seed=i'              => \$seed,
        'without-replacement' => \$without_replacement,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    die "Unexpected arguments: @arguments\n" if @arguments;
    die "--in, --out, and --quantity are required\n"
      unless defined $input_path && defined $output_path && defined $quantity;
    die "--quantity must be a positive integer\n" unless $quantity > 0;
    assert_distinct_paths( $input_path, $output_path );
    srand($seed) if defined $seed;

    my ( $spool_fh, $spool_path );
    my $source_path = $input_path;
    if ( $input_path eq '-' ) {
        ( $spool_fh, $spool_path ) = tempfile(
            'perbool-sample-XXXXXX', TMPDIR => 1, UNLINK => 1,
        );
        $source_path = $spool_path;
    }

    my $count_fh = open_fastq_reader($input_path);
    my $record_count = 0;
    while ( my $record = read_fastq_record( $count_fh, $record_count + 1 ) ) {
        $record_count++;
        write_fastq_record( $spool_fh, $record ) if $spool_fh;
    }
    close $count_fh unless $input_path eq '-';
    close $spool_fh if $spool_fh;
    die "Input FASTQ contains no records\n" if $record_count == 0;
    die "--quantity ($quantity) exceeds the number of input records "
      . "($record_count) when using --without-replacement\n"
      if $without_replacement && $quantity > $record_count;

    my @sample_indices = $without_replacement
      ? _sample_without_replacement( $record_count, $quantity )
      : map { int rand($record_count) } 1 .. $quantity;
    my %positions_for;
    for my $output_position ( 0 .. $#sample_indices ) {
        push @{ $positions_for{ $sample_indices[$output_position] } },
          $output_position;
    }

    my @sampled_records;
    my $sample_fh = open_fastq_reader($source_path);
    for my $record_index ( 0 .. $record_count - 1 ) {
        my $record = read_fastq_record( $sample_fh, $record_index + 1 );
        next unless exists $positions_for{$record_index};
        $sampled_records[$_] = $record for @{ $positions_for{$record_index} };
    }
    close $sample_fh;

    my $output_group =
      $output_path eq '-' ? undef : create_output_group($output_path);
    my $write_path = $output_group ? $output_group->{staged}[0] : '-';
    my $output_fh = open_fastq_writer($write_path);
    for my $output_position ( 0 .. $#sampled_records ) {
        my $record = $sampled_records[$output_position];
        my $header = $record->{header};
        $header =~ s/\r?\n\z//;
        my ( $read_id, @description ) = split /\s+/, $header;
        $read_id .= ':' . ( $output_position + 1 );
        my $output_header = join ' ', $read_id, @description;
        my $separator = $record->{separator};
        if ( $separator !~ /^[+]\s*\r?\n\z/ ) {
            $separator = '+' . substr( $output_header, 1 ) . "\n";
        }
        print {$output_fh}
          "$output_header\n$record->{sequence}$separator$record->{quality}";
    }
    close $output_fh unless $write_path eq '-';
    commit_output_group($output_group) if $output_group;
    return 0;
}

1;
