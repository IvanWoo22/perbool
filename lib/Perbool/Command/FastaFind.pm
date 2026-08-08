package Perbool::Command::FastaFind;

use strict;
use warnings;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fasta qw(assert_distinct_paths load_fasta_sequences);
use Perbool::IO qw(open_text_reader open_text_writer);
use Perbool::StagedOutput qw(commit_output_group create_output_group);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool fasta find (--fa INPUT.fa[.gz] | --stdin)
       (--seq SEQUENCE | --in QUERIES.txt[.gz]) [--out RESULTS.tsv[.gz]]

Report FASTA ID and 1-based inclusive end coordinate for every overlapping
literal match. FASTA and query-list inputs cannot both use standard input.
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $query, $query_path, $fasta_path, $stdin, $output_path );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'  => \$help,
        'seq|s=s' => \$query,
        'in|i=s'  => \$query_path,
        'fa|f=s'  => \$fasta_path,
        'stdin'   => \$stdin,
        'out|o=s' => \$output_path,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    die "Unexpected arguments: @arguments\n" if @arguments;
    die "Choose exactly one of --fa and --stdin\n"
      unless ( defined($fasta_path) ? 1 : 0 ) + ( $stdin ? 1 : 0 ) == 1;
    die "Choose exactly one of --seq and --in\n"
      unless ( defined($query) ? 1 : 0 ) + ( defined($query_path) ? 1 : 0 ) == 1;
    $fasta_path = '-' if $stdin;
    die "FASTA and query input cannot both use standard input\n"
      if $fasta_path eq '-' && defined($query_path) && $query_path eq '-';
    $output_path = '-' unless defined $output_path;
    assert_distinct_paths( $fasta_path, $query_path ) if defined $query_path;
    assert_distinct_paths( $fasta_path, $output_path );
    assert_distinct_paths( $query_path, $output_path ) if defined $query_path;

    my ( $fasta, $ids ) = load_fasta_sequences($fasta_path);
    my @queries;
    if ( defined $query_path ) {
        my $query_fh = open_text_reader($query_path);
        while ( my $line = <$query_fh> ) {
            $line =~ s/\r?\n\z//;
            next unless length $line;
            push @queries, $line;
        }
        close $query_fh unless $query_path eq '-';
    }
    else {
        push @queries, $query;
    }

    my $output_group =
      $output_path eq '-' ? undef : create_output_group($output_path);
    my $write_path = $output_group ? $output_group->{staged}[0] : '-';
    my $output_fh = open_text_writer($write_path);
    for my $search (@queries) {
        die "Search sequences must not be empty\n" unless length $search;
        for my $id ( @{$ids} ) {
            my $offset = 0;
            while ( ( $offset = index( $fasta->{$id}, $search, $offset ) ) >= 0 ) {
                print {$output_fh} $id, "\t", $offset + length($search), "\n";
                $offset++;
            }
        }
    }
    close $output_fh unless $write_path eq '-';
    commit_output_group($output_group) if $output_group;
    return 0;
}

1;
