package Perbool::Command::FastqSelect;

use strict;
use warnings;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fastq qw(
  assert_distinct_paths fastq_id open_fastq_reader open_fastq_writer
  read_fastq_record write_fastq_record
);
use Perbool::IO qw(open_text_reader);
use Perbool::StagedOutput qw(commit_output_group create_output_group);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    my $mode = shift;
    my $verb = $mode eq 'fetch' ? 'Retain' : 'Delete';
    return <<"USAGE";
Usage: perbool fastq $mode --name NAMES --in INPUT.fq[.gz] --out OUTPUT.fq[.gz]
       ${mode}_fastq.pl --name NAMES --in INPUT.fq --out OUTPUT.fq

$verb FASTQ records by complete first read ID. Name-list entries may be bare
IDs, \@ID, or complete FASTQ headers; blank lines are ignored. Gzip I/O is
supported and one input source may use standard input.
USAGE
}

sub run {
    my ( $mode, @arguments ) = @_;
    die "Unknown FASTQ selection mode: $mode\n"
      unless $mode eq 'fetch' || $mode eq 'delete';
    my ( $help, $name_path, $input_path, $output_path );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'   => \$help,
        'name|n=s' => \$name_path,
        'in|i=s'   => \$input_path,
        'out|o=s'  => \$output_path,
    );
    die usage_text($mode) unless $options_ok;
    if ($help) {
        print usage_text($mode);
        return 0;
    }
    die "Unexpected arguments: @arguments\n" if @arguments;
    die "--name, --in, and --out are required\n"
      unless defined $name_path && defined $input_path && defined $output_path;
    die "Only one input source may use standard input\n"
      if $name_path eq '-' && $input_path eq '-';
    assert_distinct_paths( $input_path, $output_path );
    assert_distinct_paths( $name_path,  $output_path );
    assert_distinct_paths( $name_path,  $input_path );

    my %target_id;
    my $name_fh = open_text_reader($name_path);
    while ( my $line = <$name_fh> ) {
        $line =~ s/\r?\n\z//;
        $line =~ s/^\s+|\s+$//g;
        next unless length $line;
        $line =~ s/^@//;
        my ($id) = split /\s+/, $line;
        $target_id{$id} = 1;
    }
    close $name_fh unless $name_path eq '-';

    my $output_group =
      $output_path eq '-' ? undef : create_output_group($output_path);
    my $write_path = $output_group ? $output_group->{staged}[0] : '-';
    my $input_fh = open_fastq_reader($input_path);
    my $output_fh = open_fastq_writer($write_path);
    my $record_number = 0;
    while ( my $record = read_fastq_record( $input_fh, ++$record_number ) ) {
        my $is_target = exists $target_id{ fastq_id($record) };
        write_fastq_record( $output_fh, $record )
          if ( $mode eq 'fetch' && $is_target )
          || ( $mode eq 'delete' && !$is_target );
    }
    close $input_fh unless $input_path eq '-';
    close $output_fh unless $write_path eq '-';
    commit_output_group($output_group) if $output_group;
    return 0;
}

1;
