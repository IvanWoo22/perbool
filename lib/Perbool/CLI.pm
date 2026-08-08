package Perbool::CLI;

use strict;
use warnings;

use Exporter qw(import);
use File::Spec;

our @EXPORT_OK = qw(command_rows run usage_text);

my @COMMANDS = (
    [ fasta => 'fetch',             'fetch_fasta.pl',             'fetch records by header or ID' ],
    [ fasta => 'delete',            'delete_fasta.pl',            'delete records by ID list' ],
    [ fasta => 'unique',            'unique_fasta.pl',            'deduplicate records by sequence' ],
    [ fasta => 'find',              'find_seq_from_fasta.pl',     'find literal sequence matches' ],
    [ fasta => 'extract-intervals', 'pick_seq_from_fasta_neo.pl', 'extract tabular intervals' ],
    [ fasta => 'extract-locations', 'links2fasta.pl',             'extract compact location strings' ],
    [ fasta => 'from-list',         'list2fasta.pl',              'build counted FASTA from a table' ],
    [ fasta => 'substitute',        'snp4fasta.pl',               'apply independent substitutions' ],
    [ fasta   => 'filter-composition', 'base_proportion.pl', 'filter by canonical-base fraction' ],
    [ sequence => 'reverse-complement', 'rcdna.pl',          'reverse-complement an IUPAC sequence' ],
    [ table => 'intersect-lines', 'compare_file.pl',      'intersect complete lines' ],
    [ table => 'join',            'tsv_join.pl',          'full-outer join TSV files' ],
    [ table => 'extract-after',   'format_column_name.pl','extract a suffix after a prefix' ],
    [ table => 'count-duplicates','count_duplication.pl', 'bin distinct lines by frequency' ],
    [ genome => 'bed-to-yaml', 'bed2yml.pl', 'merge BED intervals into YAML run lists' ],
    [ genome => 'transcript-coordinate', 'coordinate_position.pl', 'map transcript to genomic coordinates' ],
    [ 'small-rna' => 'tail-counts', 'mirna_count.pl', 'count exact and poly(A)-tailed reads' ],
    [ fastq => 'fetch',             'fetch_fastq.pl',             'fetch reads by ID list' ],
    [ fastq => 'delete',            'delete_fastq.pl',            'delete reads by ID list' ],
    [ fastq => 'filter',            'filter_fastq.pl',            'filter single-end reads by length' ],
    [ fastq => 'filter-paired',     'filter_pfastq.pl',           'filter paired reads by length' ],
    [ fastq => 'split-kmers',       'fastqKmer.pl',               'split reads into fixed windows' ],
    [ fastq => 'sample',            'fastq_randomsampling.pl',    'sample reads reproducibly' ],
    [ fastq => 'to-fasta',          'fastq2fasta.pl',             'convert FASTQ to FASTA' ],
    [ fastq => 'to-counts',         'fastq2count.pl',             'count distinct read sequences' ],
    [ fastq => 'single-to-paired',  'singled2paired.pl',          'create paired reads from long reads' ],
    [ qc    => 'end-bases',         'qc/end_base.pl',             'count terminal bases' ],
    [ qc    => 'lengths',           'qc/length_distribution.pl',  'summarize read lengths' ],
    [ qc    => 'paired-coordinates', 'qc/pe_coordinate.pl',      'compare paired read coordinates' ],
    [ qc    => 'summary',           'qc/se_fqc.pl',               'build single-end QC summaries' ],
);

sub command_rows {
    return map { [ @{$_} ] } @COMMANDS;
}

sub usage_text {
    my $text = <<'USAGE';
Usage: perbool GROUP COMMAND [OPTIONS]

Normalized commands:
USAGE

    my $current_group = '';
    for my $row (@COMMANDS) {
        my ( $group, $command, undef, $description ) = @{$row};
        if ( $group ne $current_group ) {
            $text .= "\n  $group\n";
            $current_group = $group;
        }
        $text .= sprintf "    %-20s %s\n", $command, $description;
    }

    $text .= <<'USAGE';

Commands with option-based interfaces support
`perbool GROUP COMMAND --help`. See the README for positional commands.
Legacy .pl entry points remain available during migration.
USAGE
    return $text;
}

sub run {
    my ( $project_root, @arguments ) = @_;

    if ( !@arguments || $arguments[0] eq '--help' || $arguments[0] eq '-h' ) {
        print usage_text();
        return 0;
    }

    if ( $arguments[0] eq 'help' ) {
        shift @arguments;
        if ( !@arguments ) {
            print usage_text();
            return 0;
        }
        push @arguments, '--help' if @arguments == 2;
    }

    my $group = shift @arguments;
    my $command = shift @arguments;
    if ( !defined $command ) {
        warn "Missing command for group '$group'\n\n";
        warn usage_text();
        return 2;
    }

    my ($row) = grep { $_->[0] eq $group && $_->[1] eq $command } @COMMANDS;
    if ( !defined $row ) {
        warn "Unknown perbool command: $group $command\n\n";
        warn usage_text();
        return 2;
    }

    my $script = File::Spec->catfile( $project_root, split m{/}, $row->[2] );
    die "Command implementation is missing: $script\n" unless -f $script;
    exec {$^X} $^X, $script, @arguments;
    die "Cannot run $group $command: $!\n";
}

1;
