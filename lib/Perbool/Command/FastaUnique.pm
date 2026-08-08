package Perbool::Command::FastaUnique;

use strict;
use warnings;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fasta qw(
  assert_distinct_paths fasta_iterator open_fasta_reader open_fasta_writer
  sequence_text write_fasta_record
);
use Perbool::StagedOutput qw(commit_output_group create_output_group);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool fasta unique --in INPUT.fa[.gz] [--out OUTPUT.fa[.gz]]
       unique_fasta.pl INPUT.fa[.gz]

Keep the first record for each distinct complete sequence. Output defaults to
standard output; the historical positional input remains accepted.
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
    if ( defined $input_path ) {
        die "Unexpected arguments: @arguments\n" if @arguments;
    }
    else {
        die usage_text() unless @arguments == 1;
        $input_path = shift @arguments;
    }
    $output_path = '-' unless defined $output_path;
    assert_distinct_paths( $input_path, $output_path );

    my $output_group =
      $output_path eq '-' ? undef : create_output_group($output_path);
    my $write_path = $output_group ? $output_group->{staged}[0] : '-';
    my $input_fh = open_fasta_reader($input_path);
    my $output_fh = open_fasta_writer($write_path);
    my $next_record = fasta_iterator($input_fh);
    my %seen_sequence;
    while ( my $record = $next_record->() ) {
        my $sequence = sequence_text($record);
        next if $seen_sequence{$sequence}++;
        write_fasta_record( $output_fh, $record );
    }
    close $input_fh unless $input_path eq '-';
    close $output_fh unless $write_path eq '-';
    commit_output_group($output_group) if $output_group;
    return 0;
}

1;
