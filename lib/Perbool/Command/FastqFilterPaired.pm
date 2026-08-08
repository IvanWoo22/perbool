package Perbool::Command::FastqFilterPaired;

use strict;
use warnings;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fastq qw(
  assert_distinct_paths open_fastq_reader open_fastq_writer paired_fastq_id
  read_fastq_record sequence_text write_fastq_record
);
use Perbool::StagedOutput qw(commit_output_group create_output_group);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool fastq filter-paired --r1 R1.fq[.gz] --r2 R2.fq[.gz]
       --out PREFIX [--min N] [--max N] [--gzip]
       filter_pfastq.pl -1 R1.fq -2 R2.fq --out PREFIX [OPTIONS]

Retain synchronized pairs only when both sequence lengths fall within the
inclusive bounds. Outputs are PREFIX_R1.fq and PREFIX_R2.fq, optionally gzip.
Final files are replaced only after both complete inputs validate.
USAGE
}

sub run {
    my @arguments = @_;
    Getopt::Long::Configure('no_ignore_case');
    my ( $help, $r1_path, $r2_path, $output_prefix, $min, $max, $gzip );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'  => \$help,
        '1|r1=s'  => \$r1_path,
        '2|r2=s'  => \$r2_path,
        'out|o=s' => \$output_prefix,
        'min|m=i' => \$min,
        'max|M=i' => \$max,
        'gzip'    => \$gzip,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    die "Unexpected arguments: @arguments\n" if @arguments;
    die "--r1, --r2, and --out are required\n"
      unless defined $r1_path && defined $r2_path && defined $output_prefix;
    die "Only one paired input may use standard input\n"
      if $r1_path eq '-' && $r2_path eq '-';
    die "--r1 and --r2 must refer to different inputs\n"
      if $r1_path eq $r2_path;
    die "--min and --max must be non-negative\n"
      if ( defined $min && $min < 0 ) || ( defined $max && $max < 0 );
    die "--min cannot be greater than --max\n"
      if defined $min && defined $max && $min > $max;
    $min = 0 unless defined $min;

    my $r1_output = $output_prefix . ( $gzip ? '_R1.fq.gz' : '_R1.fq' );
    my $r2_output = $output_prefix . ( $gzip ? '_R2.fq.gz' : '_R2.fq' );
    assert_distinct_paths( $r1_path, $r2_path );
    for my $input ( $r1_path, $r2_path ) {
        assert_distinct_paths( $input, $r1_output );
        assert_distinct_paths( $input, $r2_output );
    }
    assert_distinct_paths( $r1_output, $r2_output );

    my $output_group = create_output_group( $r1_output, $r2_output );
    my $r1_fh = open_fastq_reader($r1_path);
    my $r2_fh = open_fastq_reader($r2_path);
    my $r1_out_fh = open_fastq_writer( $output_group->{staged}[0] );
    my $r2_out_fh = open_fastq_writer( $output_group->{staged}[1] );
    my $record_number = 0;
    while ( my $record1 = read_fastq_record( $r1_fh, $record_number + 1 ) ) {
        $record_number++;
        my $record2 = read_fastq_record( $r2_fh, $record_number );
        die "Paired FASTQ files contain different numbers of records\n"
          unless defined $record2;
        die "Paired FASTQ read IDs do not match: "
          . "$record1->{header}$record2->{header}"
          unless paired_fastq_id($record1) eq paired_fastq_id($record2);
        my $length1 = length sequence_text($record1);
        my $length2 = length sequence_text($record2);
        if ( $length1 >= $min
            && $length2 >= $min
            && ( !defined $max || ( $length1 <= $max && $length2 <= $max ) ) )
        {
            write_fastq_record( $r1_out_fh, $record1 );
            write_fastq_record( $r2_out_fh, $record2 );
        }
    }
    die "Paired FASTQ files contain different numbers of records\n"
      if defined read_fastq_record( $r2_fh, $record_number + 1 );
    close $r1_fh unless $r1_path eq '-';
    close $r2_fh unless $r2_path eq '-';
    close $r1_out_fh;
    close $r2_out_fh;
    commit_output_group($output_group);
    return 0;
}

1;
