package Perbool::Command::FastaExtractIntervals;

use strict;
use warnings;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fasta qw(
  assert_distinct_paths extract_interval load_fasta_sequences
  reverse_complement rna_to_dna
);
use Perbool::IO qw(open_text_reader open_text_writer);
use Perbool::StagedOutput qw(commit_output_group create_output_group);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool fasta extract-intervals --fa INPUT.fa[.gz]
       (--in INTERVALS.txt[.gz] | --stdin) [--out OUTPUT.fa[.gz]]

Each nonblank, non-comment line contains ID START END STRAND [NAME].
Coordinates are 1-based inclusive, may be reversed, and strand is + or -.
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $interval_path, $fasta_path, $stdin, $output_path );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'         => \$help,
        'in|i|intervals=s' => \$interval_path,
        'fa|f=s'         => \$fasta_path,
        'stdin'          => \$stdin,
        'out|o=s'        => \$output_path,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    die "Unexpected arguments: @arguments\n" if @arguments;
    die "--fa is required\n" unless defined $fasta_path;
    die "Choose exactly one of --in and --stdin\n"
      unless ( defined($interval_path) ? 1 : 0 ) + ( $stdin ? 1 : 0 ) == 1;
    $interval_path = '-' if $stdin;
    die "FASTA and interval input cannot both use standard input\n"
      if $fasta_path eq '-' && $interval_path eq '-';
    $output_path = '-' unless defined $output_path;
    assert_distinct_paths( $fasta_path,    $interval_path );
    assert_distinct_paths( $fasta_path,    $output_path );
    assert_distinct_paths( $interval_path, $output_path );

    my ($fasta) = load_fasta_sequences($fasta_path);
    my $interval_fh = open_text_reader($interval_path);
    my $output_group =
      $output_path eq '-' ? undef : create_output_group($output_path);
    my $write_path = $output_group ? $output_group->{staged}[0] : '-';
    my $output_fh = open_text_writer($write_path);
    my $line_number = 0;
    while ( my $line = <$interval_fh> ) {
        $line_number++;
        $line =~ s/\r?\n\z//;
        next if $line =~ /^\s*(?:#|\z)/;
        $line =~ s/^\s+|\s+$//g;
        my ( $id, $start, $end, $strand, $name ) = split /\s+/, $line, 5;
        die "Invalid interval at line $line_number: expected ID START END STRAND [NAME]\n"
          unless defined $id && defined $start && defined $end && defined $strand;
        die "Invalid strand '$strand' at interval line $line_number; expected + or -\n"
          unless $strand eq '+' || $strand eq '-';
        die "Unknown FASTA ID '$id' at interval line $line_number\n"
          unless exists $fasta->{$id};
        my $sequence = extract_interval(
            $fasta->{$id}, $start, $end,
            "FASTA ID '$id' at interval line $line_number",
        );
        $sequence = $strand eq '-'
          ? reverse_complement($sequence)
          : rna_to_dna($sequence);
        my $header = ">$id:$start-$end($strand)";
        $header .= $name if defined $name && length $name;
        print {$output_fh} "$header\n$sequence\n";
    }
    close $interval_fh unless $interval_path eq '-';
    close $output_fh unless $write_path eq '-';
    commit_output_group($output_group) if $output_group;
    return 0;
}

1;
