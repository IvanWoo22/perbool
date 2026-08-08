package Perbool::CLI;

use strict;
use warnings;

use Exporter qw(import);
use File::Spec;
use Perbool::Help qw(command_help has_command_help);

our @EXPORT_OK = qw(command_rows run usage_text);

my @COMMANDS = (
    [ fasta => 'fetch',             'fetch_fasta.pl',             'select records by literal header text or exact first ID' ],
    [ fasta => 'delete',            'delete_fasta.pl',            'remove records whose first IDs occur in a name list' ],
    [ fasta => 'unique',            'unique_fasta.pl',            'keep the first record for each distinct complete sequence' ],
    [ fasta => 'find',              'find_seq_from_fasta.pl',     'report every overlapping literal sequence match' ],
    [ fasta => 'extract-intervals', 'pick_seq_from_fasta_neo.pl', 'extract strand-aware tabular intervals from a reference' ],
    [ fasta => 'extract-locations', 'links2fasta.pl',             'extract compact ID:START-END locations from a reference' ],
    [ fasta => 'from-list',         'list2fasta.pl',              'count a table sequence column and emit deterministic FASTA' ],
    [ fasta => 'substitute',        'snp4fasta.pl',               'apply validated substitutions independently to reference records' ],
    [ fasta   => 'filter-composition', 'base_proportion.pl', 'retain records above a canonical-base fraction' ],
    [ sequence => 'reverse-complement', 'rcdna.pl',          'reverse-complement DNA/RNA with IUPAC ambiguity symbols' ],
    [ table => 'intersect-lines', 'compare_file.pl',      'filter ordered lines by exact membership in another file' ],
    [ table => 'join',            'tsv_join.pl',          'full-outer join validated TSV files on their first column' ],
    [ table => 'extract-after',   'format_column_name.pl','extract a word suffix after a literal field prefix' ],
    [ table => 'count-duplicates','count_duplication.pl', 'summarize distinct complete lines by occurrence frequency' ],
    [ genome => 'bed-to-yaml', 'bed2yml.pl', 'merge BED intervals into 1-based inclusive YAML run lists' ],
    [ genome => 'transcript-coordinate', 'coordinate_position.pl', 'map a transcript-relative position to a genomic coordinate' ],
    [ 'small-rna' => 'tail-counts', 'mirna_count.pl', 'count exact and qualifying poly(A)-tailed reads per reference' ],
    [ literature => 'pubmed-search', 'extract_pubmed_info.pl', 'run a validated batch of PubMed searches through RISmed' ],
    [ fastq => 'fetch',             'fetch_fastq.pl',             'retain reads whose complete first IDs occur in a list' ],
    [ fastq => 'delete',            'delete_fastq.pl',            'remove reads whose complete first IDs occur in a list' ],
    [ fastq => 'filter',            'filter_fastq.pl',            'filter single-end reads by inclusive length bounds' ],
    [ fastq => 'filter-paired',     'filter_pfastq.pl',           'filter synchronized pairs using both mate lengths' ],
    [ fastq => 'split-kmers',       'fastqKmer.pl',               'split read sequences and qualities into fixed windows' ],
    [ fastq => 'sample',            'fastq_randomsampling.pl',    'randomly sample complete reads with optional reproducibility' ],
    [ fastq => 'to-fasta',          'fastq2fasta.pl',             'convert validated FASTQ records to two-line FASTA' ],
    [ fastq => 'to-counts',         'fastq2count.pl',             'count identical read sequences and emit sorted TSV' ],
    [ fastq => 'single-to-paired',  'singled2paired.pl',          'create synchronized mates from both ends of longer reads' ],
    [ qc    => 'end-bases',         'qc/end_base.pl',             'count terminal canonical bases and total FASTQ reads' ],
    [ qc    => 'lengths',           'qc/length_distribution.pl',  'produce a numeric FASTQ read-length distribution' ],
    [ qc    => 'paired-coordinates', 'qc/pe_coordinate.pl',      'identify identical or reverse-complemented mate sequences' ],
    [ qc    => 'summary',           'qc/se_fqc.pl',               'build staged TSV QC reports and an optional PDF' ],
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
        $text .= sprintf "    %-24s %s\n", $command, $description;
    }

    $text .= <<'USAGE';

Run `perbool help GROUP COMMAND` or `perbool GROUP COMMAND --help` for a
detailed description of inputs, outputs, options, defaults, and an example.
Legacy .pl entry points remain available for pipeline compatibility.
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

    if ( @arguments == 1
        && ( $arguments[0] eq '--help' || $arguments[0] eq '-h' ) )
    {
        die "Detailed command help is missing: $group $command\n"
          unless has_command_help( $group, $command );
        print command_help( $group, $command );
        return 0;
    }

    my $script = File::Spec->catfile( $project_root, split m{/}, $row->[2] );
    die "Command implementation is missing: $script\n" unless -f $script;
    exec {$^X} $^X, $script, @arguments;
    die "Cannot run $group $command: $!\n";
}

1;
