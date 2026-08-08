package Perbool::Command::FastaFetch;

use strict;
use warnings;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fasta qw(
  assert_distinct_paths fasta_id fasta_iterator open_fasta_reader
  open_fasta_writer rna_to_dna sequence_text write_fasta_record
);
use Perbool::StagedOutput qw(commit_output_group create_output_group);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool fasta fetch --string TEXT (--fasta INPUT.fa[.gz] | --stdin)
       [--exact] [--rna2dna] [--out OUTPUT.fa[.gz]]

Retain records whose complete header contains literal TEXT, or whose first ID
equals TEXT with --exact. Output defaults to standard output.
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $search, $fasta_path, $stdin, $rna2dna, $exact, $output_path );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'     => \$help,
        'string|s=s' => \$search,
        'fasta|f=s'  => \$fasta_path,
        'stdin'      => \$stdin,
        'rna2dna'    => \$rna2dna,
        'exact'      => \$exact,
        'out|o=s'    => \$output_path,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    die "Unexpected arguments: @arguments\n" if @arguments;
    die "--string is required\n" unless defined $search && length $search;
    die "Choose exactly one of --fasta and --stdin\n"
      unless ( defined($fasta_path) ? 1 : 0 ) + ( $stdin ? 1 : 0 ) == 1;
    $fasta_path = '-' if $stdin;
    $output_path = '-' unless defined $output_path;
    assert_distinct_paths( $fasta_path, $output_path );

    my $output_group =
      $output_path eq '-' ? undef : create_output_group($output_path);
    my $write_path = $output_group ? $output_group->{staged}[0] : '-';
    my $input_fh = open_fasta_reader($fasta_path);
    my $output_fh = open_fasta_writer($write_path);
    my $next_record = fasta_iterator($input_fh);
    while ( my $record = $next_record->() ) {
        my $matches = $exact
          ? fasta_id($record) eq $search
          : index( $record->{header}, $search ) >= 0;
        next unless $matches;
        if ($rna2dna) {
            $record->{sequence} = rna_to_dna( sequence_text($record) );
        }
        write_fasta_record( $output_fh, $record );
    }
    close $input_fh unless $fasta_path eq '-';
    close $output_fh unless $write_path eq '-';
    commit_output_group($output_group) if $output_group;
    return 0;
}

1;
