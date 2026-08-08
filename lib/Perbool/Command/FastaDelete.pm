package Perbool::Command::FastaDelete;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fasta qw(
  assert_distinct_paths fasta_id fasta_iterator open_fasta_reader
  open_fasta_writer write_fasta_record
);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool fasta delete --name NAMES --in INPUT.fa[.gz] --out OUTPUT.fa[.gz]

Delete FASTA records whose complete first IDs occur in NAMES. List entries may
be bare IDs, >ID, or complete FASTA headers; blank lines are ignored.
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $name_list, $input_path, $output_path );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'   => \$help,
        'name|n=s' => \$name_list,
        'in|i=s'   => \$input_path,
        'out|o=s'  => \$output_path,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    die "Unexpected arguments: @arguments\n" if @arguments;
    die "--name, --in, and --out are required\n"
      unless defined $name_list && defined $input_path && defined $output_path;
    assert_distinct_paths( $input_path, $output_path );

    open my $name_fh, '<', $name_list;
    my %delete_id;
    while ( my $line = <$name_fh> ) {
        $line =~ s/\r?\n\z//;
        $line =~ s/^\s+|\s+$//g;
        next unless length $line;
        $line =~ s/^>//;
        my ($id) = split /\s+/, $line;
        $delete_id{$id} = 1;
    }
    close $name_fh;

    my $input_fh = open_fasta_reader($input_path);
    my $output_fh = open_fasta_writer($output_path);
    my $next_record = fasta_iterator($input_fh);
    while ( my $record = $next_record->() ) {
        next if exists $delete_id{ fasta_id($record) };
        write_fasta_record( $output_fh, $record );
    }
    close $input_fh unless $input_path eq '-';
    close $output_fh unless $output_path eq '-';
    return 0;
}

1;
