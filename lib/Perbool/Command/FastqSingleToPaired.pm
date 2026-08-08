package Perbool::Command::FastqSingleToPaired;

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
Usage: perbool fastq single-to-paired --in INPUT.fq[.gz] --length N
       --r1 R1.fq[.gz] --r2 R2.fq[.gz]

Create synchronized reads from the two ends of each sufficiently long input
read. R2 sequence is reverse-complemented and its quality string is reversed.
Legacy --R1/--R2 and -1/-2 option names remain accepted.
USAGE
}

sub _reverse_complement {
    my $sequence = reverse shift;
    $sequence =~ tr/Uu/Tt/;
    $sequence =~ tr/AGCTagct/TCGAtcga/;
    return $sequence;
}

sub run {
    my @arguments = @_;
    Getopt::Long::Configure('no_ignore_case');
    my ( $help, $input_path, $length, $r1_path, $r2_path );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'     => \$help,
        'in|i=s'     => \$input_path,
        'length|l=i' => \$length,
        'R1|r1|1=s'  => \$r1_path,
        'R2|r2|2=s'  => \$r2_path,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    die "Unexpected arguments: @arguments\n" if @arguments;
    die "--in, --length, --r1, and --r2 are required\n"
      unless defined $input_path
      && defined $length
      && defined $r1_path
      && defined $r2_path;
    die "--length must be a positive integer\n" unless $length > 0;
    die "--r1 and --r2 must refer to different files\n"
      if $r1_path eq $r2_path;
    assert_distinct_paths( $input_path, $r1_path );
    assert_distinct_paths( $input_path, $r2_path );
    assert_distinct_paths( $r1_path,    $r2_path );

    my @file_outputs = grep { $_ ne '-' } ( $r1_path, $r2_path );
    my $output_group = @file_outputs ? create_output_group(@file_outputs) : undef;
    my %staged_for;
    if ($output_group) {
        @staged_for{ @{ $output_group->{final} } } = @{ $output_group->{staged} };
    }
    my $r1_write_path = $r1_path eq '-' ? '-' : $staged_for{$r1_path};
    my $r2_write_path = $r2_path eq '-' ? '-' : $staged_for{$r2_path};
    my $input_fh = open_fastq_reader($input_path);
    my $r1_fh = open_fastq_writer($r1_write_path);
    my $r2_fh = open_fastq_writer($r2_write_path);
    my $record_number = 0;
    while ( my $record = read_fastq_record( $input_fh, ++$record_number ) ) {
        my $header = $record->{header};
        $header =~ s/\r?\n\z//;
        my ( $read_id, @description ) = split /\s+/, $header;
        my $sequence = sequence_text($record);
        next if length($sequence) < $length;
        my $quality = quality_text($record);
        my $description = @description ? ' ' . join( ' ', @description ) : '';
        my $r1_sequence = substr( $sequence, 0, $length );
        my $r2_sequence = _reverse_complement( substr( $sequence, -$length ) );
        my $r1_quality = substr( $quality, 0, $length );
        my $r2_quality = reverse substr( $quality, -$length );
        print {$r1_fh} "$read_id 1$description\n$r1_sequence\n+\n$r1_quality\n";
        print {$r2_fh} "$read_id 2$description\n$r2_sequence\n+\n$r2_quality\n";
    }
    close $input_fh unless $input_path eq '-';
    close $r1_fh unless $r1_write_path eq '-';
    close $r2_fh unless $r2_write_path eq '-';
    commit_output_group($output_group) if $output_group;
    return 0;
}

1;
