package Perbool::Command::FastaExtractLocations;

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

our @EXPORT_OK = qw(decode_location run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool fasta extract-locations --fa INPUT.fa[.gz]
       (--in LOCATIONS.txt[.gz] | --stdin) [--out OUTPUT.fa[.gz]]

Locations use ID:START-END or PREFIX.ID(-):START-END. Tab-separated locations
may share one line; coordinates are 1-based inclusive and output wraps at 70.
USAGE
}

sub decode_location {
    my ( $range, $sequences, $source_line ) = @_;
    $range =~ s/^\s+|\s+$//g;
    my ( $raw_id, $strand, $start, $end ) =
      $range =~ /\A(.+?)(?:\(([+-]|-?1)\))?:(\d+)(?:[_-](\d+))?\z/
      or die "Invalid location '$range' at line $source_line\n";
    $end = $start unless defined $end;
    $strand = '+' unless defined $strand;
    $strand = '+' if $strand eq '1';
    $strand = '-' if $strand eq '-1';

    my $id = $raw_id;
    if ( !exists $sequences->{$id} ) {
        my @parts = split /[.]/, $raw_id;
        shift @parts;
        while (@parts) {
            my $candidate = join '.', @parts;
            if ( exists $sequences->{$candidate} ) {
                $id = $candidate;
                last;
            }
            shift @parts;
        }
    }
    die "Unknown FASTA ID '$raw_id' at location line $source_line\n"
      unless exists $sequences->{$id};
    return ( $id, $start, $end, $strand );
}

sub run {
    my @arguments = @_;
    my ( $help, $location_path, $fasta_path, $stdin, $output_path );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'         => \$help,
        'in|i|locations=s' => \$location_path,
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
      unless ( defined($location_path) ? 1 : 0 ) + ( $stdin ? 1 : 0 ) == 1;
    $location_path = '-' if $stdin;
    die "FASTA and location input cannot both use standard input\n"
      if $fasta_path eq '-' && $location_path eq '-';
    $output_path = '-' unless defined $output_path;
    assert_distinct_paths( $fasta_path,    $location_path );
    assert_distinct_paths( $fasta_path,    $output_path );
    assert_distinct_paths( $location_path, $output_path );

    my ($fasta) = load_fasta_sequences($fasta_path);
    my $location_fh = open_text_reader($location_path);
    my $output_group =
      $output_path eq '-' ? undef : create_output_group($output_path);
    my $write_path = $output_group ? $output_group->{staged}[0] : '-';
    my $output_fh = open_text_writer($write_path);
    my $line_number = 0;
    while ( my $line = <$location_fh> ) {
        $line_number++;
        $line =~ s/\r?\n\z//;
        next if $line =~ /^\s*(?:#|\z)/;
        for my $range ( split /\t/, $line ) {
            my ( $id, $start, $end, $strand ) =
              decode_location( $range, $fasta, $line_number );
            my $sequence = extract_interval(
                $fasta->{$id}, $start, $end,
                "FASTA ID '$id' at location line $line_number",
            );
            $sequence = $strand eq '-'
              ? reverse_complement($sequence)
              : rna_to_dna($sequence);
            print {$output_fh} ">$range\n";
            while ( length $sequence ) {
                print {$output_fh} substr( $sequence, 0, 70, '' ), "\n";
            }
        }
    }
    close $location_fh unless $location_path eq '-';
    close $output_fh unless $write_path eq '-';
    commit_output_group($output_group) if $output_group;
    return 0;
}

1;
