package Perbool::Command::QcPairedCoordinates;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use File::Temp qw(tempfile);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fasta qw(reverse_complement);
use Perbool::Fastq qw(
  assert_distinct_paths open_fastq_reader paired_fastq_id read_fastq_record
  sequence_text
);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool qc paired-coordinates --r1 R1.fq[.gz] --r2 R2.fq[.gz]
       qc/pe_coordinate.pl R1.fq[.gz] R2.fq[.gz]

Print R1 sequences whose paired R2 sequence is identical or its reverse
complement. Read IDs and record counts must remain synchronized. One input may
be standard input; results are emitted only after both files validate.
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $r1_path, $r2_path );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h' => \$help,
        'r1=s'   => \$r1_path,
        'r2=s'   => \$r2_path,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    if (@arguments) {
        die "Positional inputs cannot be combined with --r1 or --r2\n"
          if defined $r1_path || defined $r2_path;
        die usage_text() unless @arguments == 2;
        ( $r1_path, $r2_path ) = @arguments;
    }
    die "--r1 and --r2 are required\n"
      unless defined $r1_path && defined $r2_path;
    die "Only one paired input may use standard input\n"
      if $r1_path eq '-' && $r2_path eq '-';
    die "R1 and R2 must refer to different inputs\n" if $r1_path eq $r2_path;
    assert_distinct_paths( $r1_path, $r2_path );

    my $r1_fh = open_fastq_reader($r1_path);
    my $r2_fh = open_fastq_reader($r2_path);
    my ($matches_fh) = tempfile( UNLINK => 1 );
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
        my $normalized1 = uc $sequence1;
        my $normalized2 = uc $sequence2;
        print {$matches_fh} "$sequence1\n"
          if $normalized1 eq $normalized2
          || $normalized1 eq uc( reverse_complement($sequence2) );
    }
    die "Paired FASTQ files contain different numbers of records\n"
      if defined read_fastq_record( $r2_fh, $record_number + 1 );
    close $r1_fh unless $r1_path eq '-';
    close $r2_fh unless $r2_path eq '-';

    seek $matches_fh, 0, 0;
    while ( read $matches_fh, my $buffer, 64 * 1024 ) {
        print $buffer;
    }
    close $matches_fh;
    return 0;
}

1;
