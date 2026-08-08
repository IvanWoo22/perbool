package Perbool::Command::FastqSplitKmers;

use strict;
use warnings;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fastq qw(
  assert_distinct_paths open_fastq_reader open_fastq_writer quality_text
  read_fastq_record sequence_text
);
use Perbool::StagedOutput qw(commit_output_group create_output_group);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool fastq split-kmers --in INPUT.fq[.gz] --out OUTPUT.fq[.gz]
       --kmer N [--step N] [--prefix TEXT]

Split each sufficiently long read into fixed-length windows. The step defaults
to 1, and a final window ending at the read boundary is included exactly once.
USAGE
}

sub _windows {
    my ( $text, $length, $step ) = @_;
    my $text_length = length $text;
    my ( @windows, $last_start );
    for ( my $start = 0 ; $start + $length <= $text_length ; $start += $step ) {
        push @windows, substr( $text, $start, $length );
        $last_start = $start;
    }
    my $tail_start = $text_length - $length;
    if ( @windows && $last_start != $tail_start ) {
        push @windows, substr( $text, $tail_start, $length );
    }
    return \@windows;
}

sub run {
    my @arguments = @_;
    Getopt::Long::Configure('no_ignore_case');
    my ( $help, $input_path, $output_path, $kmer, $step, $prefix );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'   => \$help,
        'in|i=s'   => \$input_path,
        'out|o=s'  => \$output_path,
        'kmer|K=i' => \$kmer,
        'step|S=i' => \$step,
        'prefix=s' => \$prefix,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    die "Unexpected arguments: @arguments\n" if @arguments;
    die "--in, --out, and --kmer are required\n"
      unless defined $input_path && defined $output_path && defined $kmer;
    $step = 1 unless defined $step;
    die "--kmer and --step must be positive integers\n"
      unless $kmer > 0 && $step > 0;
    assert_distinct_paths( $input_path, $output_path );
    $prefix = defined $prefix ? ':' . $prefix : '';

    my $output_group =
      $output_path eq '-' ? undef : create_output_group($output_path);
    my $write_path = $output_group ? $output_group->{staged}[0] : '-';
    my $input_fh = open_fastq_reader($input_path);
    my $output_fh = open_fastq_writer($write_path);
    my $record_number = 0;
    while ( my $record = read_fastq_record( $input_fh, ++$record_number ) ) {
        my $header = $record->{header};
        $header =~ s/\r?\n\z//;
        my ( $read_id, @description ) = split /\s+/, $header;
        my $sequence = sequence_text($record);
        next if length($sequence) < $kmer;
        my $sequence_windows = _windows( $sequence, $kmer, $step );
        my $quality_windows = _windows( quality_text($record), $kmer, $step );
        for my $index ( 0 .. $#{$sequence_windows} ) {
            my $window_header = $read_id . $prefix . '_' . $index;
            $window_header .= ' ' . join( ' ', @description ) if @description;
            print {$output_fh}
              "$window_header\n$sequence_windows->[$index]\n+\n$quality_windows->[$index]\n";
        }
    }
    close $input_fh unless $input_path eq '-';
    close $output_fh unless $write_path eq '-';
    commit_output_group($output_group) if $output_group;
    return 0;
}

1;
