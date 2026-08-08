package Perbool::Command::FastqToFasta;

use strict;
use warnings;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fastq qw(
  assert_distinct_paths open_fastq_reader read_fastq_record sequence_text
);
use Perbool::IO qw(open_text_writer);
use Perbool::StagedOutput qw(commit_output_group create_output_group);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool fastq to-fasta [--in INPUT.fq[.gz]] [--out OUTPUT.fa[.gz]]
       fastq2fasta.pl < INPUT.fq > OUTPUT.fa

Convert validated FASTQ records to two-line FASTA while preserving complete
headers. Input and output default to standard streams; gzip files are supported.
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $input_path, $output_path );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h' => \$help,
        'in|i=s' => \$input_path,
        'out|o=s' => \$output_path,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    die "Unexpected arguments: @arguments\n" if @arguments;
    $input_path = '-' unless defined $input_path;
    $output_path = '-' unless defined $output_path;
    assert_distinct_paths( $input_path, $output_path );

    my $output_group =
      $output_path eq '-' ? undef : create_output_group($output_path);
    my $write_path = $output_group ? $output_group->{staged}[0] : '-';
    my $input_fh = open_fastq_reader($input_path);
    my $output_fh = open_text_writer($write_path);
    my $record_number = 0;
    while ( my $record = read_fastq_record( $input_fh, ++$record_number ) ) {
        my $header = $record->{header};
        $header =~ s/^@/>/;
        $header =~ s/\r?\n\z//;
        print {$output_fh} "$header\n", sequence_text($record), "\n";
    }
    close $input_fh unless $input_path eq '-';
    close $output_fh unless $write_path eq '-';
    commit_output_group($output_group) if $output_group;
    return 0;
}

1;
