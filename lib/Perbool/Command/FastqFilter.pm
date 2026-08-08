package Perbool::Command::FastqFilter;

use strict;
use warnings;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fastq qw(
  assert_distinct_paths open_fastq_reader open_fastq_writer
  read_fastq_record sequence_text write_fastq_record
);
use Perbool::StagedOutput qw(commit_output_group create_output_group);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool fastq filter --in INPUT.fq[.gz] --out OUTPUT.fq[.gz]
       [--min N] [--max N]

Retain reads whose sequence lengths fall within the inclusive bounds. The
minimum defaults to 0 and no maximum is applied unless --max is supplied.
USAGE
}

sub run {
    my @arguments = @_;
    Getopt::Long::Configure('no_ignore_case');
    my ( $help, $input_path, $output_path, $min, $max );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'  => \$help,
        'in|i=s'  => \$input_path,
        'out|o=s' => \$output_path,
        'min|m=i' => \$min,
        'max|M=i' => \$max,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    die "Unexpected arguments: @arguments\n" if @arguments;
    die "--in and --out are required\n"
      unless defined $input_path && defined $output_path;
    die "--min and --max must be non-negative\n"
      if ( defined $min && $min < 0 ) || ( defined $max && $max < 0 );
    die "--min cannot be greater than --max\n"
      if defined $min && defined $max && $min > $max;
    assert_distinct_paths( $input_path, $output_path );
    $min = 0 unless defined $min;

    my $output_group =
      $output_path eq '-' ? undef : create_output_group($output_path);
    my $write_path = $output_group ? $output_group->{staged}[0] : '-';
    my $input_fh = open_fastq_reader($input_path);
    my $output_fh = open_fastq_writer($write_path);
    my $record_number = 0;
    while ( my $record = read_fastq_record( $input_fh, ++$record_number ) ) {
        my $length = length sequence_text($record);
        write_fastq_record( $output_fh, $record )
          if $length >= $min && ( !defined $max || $length <= $max );
    }
    close $input_fh unless $input_path eq '-';
    close $output_fh unless $write_path eq '-';
    commit_output_group($output_group) if $output_group;
    return 0;
}

1;
