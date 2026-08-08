package Perbool::Help;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(command_help has_command_help);

my %HELP = (
    'fasta fetch' => {
        usage => 'perbool fasta fetch --string TEXT (--fasta INPUT.fa[.gz] | --stdin) [--exact] [--rna2dna] [--out OUTPUT.fa[.gz]]',
        description => 'Select FASTA records by literal header text or by an exact first record ID.',
        input => 'A validated multiline FASTA file, gzip FASTA, or standard input.',
        output => 'Matching records in canonical two-line FASTA; standard output by default.',
        options => [
            [ '--string, -s TEXT', 'Required literal search text.' ],
            [ '--fasta, -f FILE', 'Read FASTA records from FILE.' ],
            [ '--stdin', 'Read FASTA records from standard input instead of --fasta.' ],
            [ '--exact', 'Match the complete first ID instead of searching the full header.' ],
            [ '--rna2dna', 'Convert U/u to T/t in selected sequences.' ],
            [ '--out, -o FILE', 'Write plain or .gz FASTA to FILE; default: standard output.' ],
        ],
        example => 'perbool fasta fetch -f transcripts.fa.gz -s transcript_001 --exact -o transcript_001.fa',
    },
    'fasta delete' => {
        usage => 'perbool fasta delete --name NAMES --in INPUT.fa[.gz] --out OUTPUT.fa[.gz]',
        description => 'Remove FASTA records whose complete first IDs occur in a name list.',
        input => 'Validated FASTA plus a list containing bare IDs, >ID values, or complete headers.',
        output => 'All nonlisted records in source order; .gz output is selected by suffix.',
        options => [
            [ '--name, -n FILE', 'Required ID-list file; blank lines are ignored.' ],
            [ '--in, -i FILE', 'Required input FASTA path.' ],
            [ '--out, -o FILE', 'Required output FASTA path.' ],
        ],
        example => 'perbool fasta delete -n remove.txt -i input.fa.gz -o retained.fa.gz',
    },
    'fasta unique' => {
        usage => 'perbool fasta unique --in INPUT.fa[.gz] [--out OUTPUT.fa[.gz]]',
        description => 'Deduplicate FASTA records by complete sequence while keeping the first occurrence.',
        input => 'Validated multiline plain or gzip FASTA; a legacy positional input is also accepted.',
        output => 'Canonical two-line FASTA in first-occurrence order; standard output by default.',
        options => [
            [ '--in, -i FILE', 'Input FASTA path; use - for standard input.' ],
            [ '--out, -o FILE', 'Plain or .gz output path; default: standard output.' ],
        ],
        example => 'perbool fasta unique -i reads.fa.gz -o unique.fa.gz',
    },
    'fasta find' => {
        usage => 'perbool fasta find (--fa INPUT.fa[.gz] | --stdin) (--seq SEQUENCE | --in QUERIES.txt[.gz]) [--out RESULTS.tsv[.gz]]',
        description => 'Find every overlapping literal sequence match in every FASTA record.',
        input => 'One FASTA source and either one query sequence or a nonblank query-list file.',
        output => 'FASTA_ID and 1-based inclusive match-end coordinate as two TSV columns.',
        options => [
            [ '--fa, -f FILE', 'Search records in FILE.' ],
            [ '--stdin', 'Read FASTA records from standard input.' ],
            [ '--seq, -s TEXT', 'Search for one literal sequence.' ],
            [ '--in, -i FILE', 'Read query sequences from a plain or .gz file.' ],
            [ '--out, -o FILE', 'Write plain or .gz TSV; default: standard output.' ],
        ],
        example => 'perbool fasta find --fa genome.fa.gz --seq ACGT --out matches.tsv',
    },
    'fasta extract-intervals' => {
        usage => 'perbool fasta extract-intervals --fa INPUT.fa[.gz] (--in INTERVALS.txt[.gz] | --stdin) [--out OUTPUT.fa[.gz]]',
        description => 'Extract named, strand-aware intervals described in a five-column text format.',
        input => 'Rows are ID START END STRAND [NAME]; coordinates are 1-based inclusive and may be reversed.',
        output => 'One canonical FASTA record per interval; negative-strand sequences are reverse-complemented.',
        options => [
            [ '--fa, -f FILE', 'Required reference FASTA.' ],
            [ '--in, -i, --intervals FILE', 'Read interval rows from FILE; .gz is supported.' ],
            [ '--stdin', 'Read interval rows from standard input.' ],
            [ '--out, -o FILE', 'Write plain or .gz FASTA; default: standard output.' ],
        ],
        example => 'perbool fasta extract-intervals -f genome.fa.gz -i intervals.tsv -o intervals.fa.gz',
    },
    'fasta extract-locations' => {
        usage => 'perbool fasta extract-locations --fa INPUT.fa[.gz] (--in LOCATIONS.txt[.gz] | --stdin) [--out OUTPUT.fa[.gz]]',
        description => 'Extract intervals written as compact ID:START-END location strings.',
        input => 'One or more tab-separated locations per line; (+), (-), (1), and (-1) strand tags are accepted.',
        output => 'FASTA named with the original location text and wrapped at 70 sequence bases.',
        options => [
            [ '--fa, -f FILE', 'Required reference FASTA.' ],
            [ '--in, -i, --locations FILE', 'Read locations from a plain or .gz file.' ],
            [ '--stdin', 'Read location rows from standard input.' ],
            [ '--out, -o FILE', 'Write plain or .gz FASTA; default: standard output.' ],
        ],
        example => 'perbool fasta extract-locations -f genome.fa.gz -i locations.txt -o regions.fa',
    },
    'fasta from-list' => {
        usage => 'perbool fasta from-list --col NUMBER (--file TABLE | --stdin) [--sep TEXT] [--rna2dna]',
        description => 'Count sequences in a selected table column and convert distinct values to FASTA.',
        input => 'A delimited text table from a file or standard input; column numbering starts at 1.',
        output => 'Deterministic FASTA with LENGTH and REPEAT metadata, in first-occurrence order.',
        options => [
            [ '--col, -c N', 'Required 1-based sequence column.' ],
            [ '--file, -f FILE', 'Read the table from FILE.' ],
            [ '--stdin', 'Read the table from standard input.' ],
            [ '--sep, -s TEXT', 'Literal field separator; default: tab.' ],
            [ '--rna2dna', 'Convert U/u to T/t before counting.' ],
        ],
        example => 'perbool fasta from-list --file reads.tsv --col 2 --rna2dna > collapsed.fa',
    },
    'fasta substitute' => {
        usage => 'perbool fasta substitute --fa REFERENCE.fa[.gz] (--in VARIANTS | --stdin)',
        description => 'Apply each validated sequence substitution independently to a FASTA reference.',
        input => 'Variant rows contain FASTA_ID POSITION REF ALT with a 1-based position and IUPAC alleles.',
        output => 'One FASTA record per variant on standard output; the reference is not modified cumulatively.',
        options => [
            [ '--fa, -f FILE', 'Required reference FASTA.' ],
            [ '--in, -i FILE', 'Read variant rows from FILE.' ],
            [ '--stdin', 'Read variant rows from standard input.' ],
        ],
        example => 'perbool fasta substitute -f reference.fa.gz -i variants.tsv > alternates.fa',
    },
    'fasta filter-composition' => {
        usage => 'perbool fasta filter-composition --base BASE --fraction-above FRACTION [--in INPUT.fa[.gz]]',
        description => 'Retain FASTA records exceeding a selected canonical-base fraction.',
        input => 'Validated FASTA; standard input is used when --in is omitted.',
        output => 'Matching FASTA records on standard output, preserving their source order.',
        options => [
            [ '--base, -b A|C|G|T', 'Canonical base used in the numerator.' ],
            [ '--fraction-above, -f N', 'Strict threshold from 0 to 1.' ],
            [ '--in, -i FILE', 'Read plain or gzip FASTA from FILE.' ],
        ],
        example => 'perbool fasta filter-composition -b A -f 0.60 -i input.fa.gz > a-rich.fa',
    },
    'sequence reverse-complement' => {
        usage => 'perbool sequence reverse-complement SEQUENCE',
        description => 'Reverse-complement DNA or RNA with standard IUPAC ambiguity symbols plus X.',
        input => 'A sequence argument, or - to read and concatenate whitespace-separated standard input.',
        output => 'One reverse-complemented sequence line on standard output.',
        options => [],
        example => 'perbool sequence reverse-complement ACGTRYMK',
    },
    'table intersect-lines' => {
        usage => 'perbool table intersect-lines --left FILE1 --right FILE2 [--unique]',
        description => 'Print exact complete lines from the right input that also occur in the left input.',
        input => 'Two plain or gzip text files; at most one may be standard input (-).',
        output => 'Matching lines in right-input order, retaining repeats by default.',
        options => [
            [ '--left, -l FILE', 'Required membership-set input.' ],
            [ '--right, -r FILE', 'Required ordered input to filter.' ],
            [ '--unique, -u', 'Emit each matching line at most once.' ],
        ],
        example => 'perbool table intersect-lines -l expected.txt -r observed.txt --unique',
    },
    'table join' => {
        usage => 'perbool table join [--missing TEXT] TABLE1.tsv [TABLE2.tsv ...]',
        description => 'Perform a sorted full-outer join of tab-delimited tables on their first column.',
        input => 'One or more nonempty tables with unique nonempty keys and a consistent width per file.',
        output => 'Joined TSV on standard output, sorted lexically by key.',
        options => [
            [ '--missing, -m TEXT', 'Placeholder for absent value cells; default: NA.' ],
        ],
        example => 'perbool table join sample-a.tsv sample-b.tsv.gz > joined.tsv',
    },
    'table extract-after' => {
        usage => 'perbool table extract-after --column N --prefix TEXT [--in TABLE.tsv[.gz]]',
        description => 'Replace one TSV field with the contiguous word characters after a literal prefix.',
        input => 'Tab-delimited rows from FILE or standard input; column numbering starts at 1.',
        output => 'Transformed TSV rows on standard output.',
        options => [
            [ '--column, -c N', 'Required 1-based column to transform.' ],
            [ '--prefix, -p TEXT', 'Required literal marker preceding the desired suffix.' ],
            [ '--in, -i FILE', 'Read plain or gzip TSV from FILE.' ],
        ],
        example => 'perbool table extract-after -c 2 -p ID= -i attributes.tsv > ids.tsv',
    },
    'table count-duplicates' => {
        usage => 'perbool table count-duplicates [--in LINES.txt[.gz]]',
        description => 'Summarize how many distinct complete lines occur at each frequency.',
        input => 'Plain or gzip text; standard input is the default and blank lines count as values.',
        output => 'OCCURRENCES and DISTINCT_LINES columns sorted by numeric occurrence count.',
        options => [
            [ '--in, -i FILE', 'Read lines from FILE instead of standard input.' ],
        ],
        example => 'perbool table count-duplicates --in barcodes.txt.gz > frequency-bins.tsv',
    },
    'genome bed-to-yaml' => {
        usage => 'perbool genome bed-to-yaml [--in INPUT.bed[.gz]]',
        description => 'Merge BED intervals by reference and serialize 1-based inclusive run lists as YAML.',
        input => 'At least three BED columns using 0-based, half-open coordinates; comments are ignored.',
        output => 'A deterministic YAML mapping on standard output, sorted by reference name.',
        options => [
            [ '--in, -i FILE', 'Read plain or gzip BED from FILE; default: standard input.' ],
        ],
        example => 'perbool genome bed-to-yaml -i regions.bed.gz > regions.yml',
    },
    'genome transcript-coordinate' => {
        usage => 'perbool genome transcript-coordinate --transcript ID --position N [--in RANGES.tsv[.gz]]',
        description => 'Map a 1-based position along merged transcript ranges to a genomic coordinate.',
        input => 'REFERENCE START END STRAND GFF_ATTRIBUTES rows with 1-based inclusive coordinates.',
        output => 'REFERENCE and genomic coordinate as two tab-delimited fields.',
        options => [
            [ '--transcript, -t ID', 'Required Parent transcript ID.' ],
            [ '--position, -p N', 'Required positive transcript position.' ],
            [ '--in, -i FILE', 'Read range rows from plain/gzip FILE; default: standard input.' ],
        ],
        example => 'perbool genome transcript-coordinate -t ENST00000335137.4 -p 120 -i ranges.tsv.gz',
    },
    'small-rna tail-counts' => {
        usage => 'perbool small-rna tail-counts --counts READ_COUNTS.tsv[.gz] --fasta REFERENCES.fa[.gz]',
        description => 'Report exact and poly(A)-tailed read counts for every reference sequence.',
        input => 'SEQUENCE COUNT TSV plus reference FASTA; sequences are compared case-insensitively.',
        output => 'Complete FASTA header, exact count, and qualifying tail count as three TSV columns.',
        options => [
            [ '--counts, -c FILE', 'Required collapsed read-count table.' ],
            [ '--fasta, -f FILE', 'Required reference FASTA.' ],
        ],
        example => 'perbool small-rna tail-counts -c reads.tsv.gz -f mature.fa.gz > tails.tsv',
    },
    'literature pubmed-search' => {
        usage => 'perbool literature pubmed-search --queries QUERIES.txt[.gz] [--out RESULTS.txt[.gz]] [OPTIONS]',
        description => 'Run the bundled RISmed backend for each nonblank PubMed query as one validated batch.',
        input => 'One query per line plus the bundled or user-supplied R backend script.',
        output => 'Query-framed CSV result blocks; output opens only after every search succeeds.',
        options => [
            [ '--queries, -q FILE', 'Required plain or gzip query list.' ],
            [ '--out, -o FILE', 'Plain/gzip result file; default: standard output.' ],
            [ '--min-year N', 'Minimum publication year; default: 2010.' ],
            [ '--max-year N', 'Maximum publication year; default: current year.' ],
            [ '--retmax N', 'Maximum results per query; default: 100.' ],
            [ '--work-dir, -w DIR', 'Directory for temporary backend files.' ],
            [ '--rscript PROGRAM', 'Rscript executable name or path.' ],
            [ '--r-script FILE', 'Alternative R backend script.' ],
        ],
        example => 'perbool literature pubmed-search -q topics.txt --min-year 2020 -o results.txt',
    },
    'fastq fetch' => _fastq_select_help('fetch'),
    'fastq delete' => _fastq_select_help('delete'),
    'fastq filter' => {
        usage => 'perbool fastq filter --in INPUT.fq[.gz] --out OUTPUT.fq[.gz] [--min N] [--max N]',
        description => 'Retain single-end reads whose sequence lengths lie within inclusive bounds.',
        input => 'Validated plain, gzip, or standard-input FASTQ.',
        output => 'Filtered FASTQ; file output replaces its destination only after complete validation.',
        options => [
            [ '--in, -i FILE', 'Required input FASTQ; use - for standard input.' ],
            [ '--out, -o FILE', 'Required plain/gzip output; use - for standard output.' ],
            [ '--min, -m N', 'Minimum read length; default: 0.' ],
            [ '--max, -M N', 'Maximum read length; default: no limit.' ],
        ],
        example => 'perbool fastq filter -i reads.fq.gz -o filtered.fq.gz -m 20 -M 30',
    },
    'fastq filter-paired' => {
        usage => 'perbool fastq filter-paired --r1 R1.fq[.gz] --r2 R2.fq[.gz] --out PREFIX [--min N] [--max N] [--gzip]',
        description => 'Retain synchronized pairs only when both read lengths lie within inclusive bounds.',
        input => 'Two validated FASTQ sources with matching paired IDs and equal record counts.',
        output => 'PREFIX_R1.fq and PREFIX_R2.fq, or .fq.gz files with --gzip.',
        options => [
            [ '--r1, -1 FILE', 'Required R1 input.' ],
            [ '--r2, -2 FILE', 'Required R2 input.' ],
            [ '--out, -o PREFIX', 'Required output prefix.' ],
            [ '--min, -m N', 'Minimum length for each mate; default: 0.' ],
            [ '--max, -M N', 'Maximum length for each mate; default: no limit.' ],
            [ '--gzip', 'Compress both output files.' ],
        ],
        example => 'perbool fastq filter-paired --r1 R1.fq.gz --r2 R2.fq.gz -o kept -m 20 --gzip',
    },
    'fastq split-kmers' => {
        usage => 'perbool fastq split-kmers --in INPUT.fq[.gz] --out OUTPUT.fq[.gz] --kmer N [--step N] [--prefix TEXT]',
        description => 'Split each sufficiently long read into fixed-length sequence and quality windows.',
        input => 'Validated FASTQ; reads shorter than the requested window are skipped.',
        output => 'Window FASTQ records numbered from zero, including the terminal window exactly once.',
        options => [
            [ '--in, -i FILE', 'Required input FASTQ.' ],
            [ '--out, -o FILE', 'Required plain or gzip output FASTQ.' ],
            [ '--kmer, -K N', 'Required positive window length.' ],
            [ '--step, -S N', 'Positive distance between starts; default: 1.' ],
            [ '--prefix TEXT', 'Insert :TEXT before each window index.' ],
        ],
        example => 'perbool fastq split-kmers -i reads.fq.gz -o windows.fq.gz -K 20 -S 5',
    },
    'fastq sample' => {
        usage => 'perbool fastq sample --in INPUT.fq[.gz] --out OUTPUT.fq[.gz] --quantity N [--seed N] [--without-replacement]',
        description => 'Randomly sample complete FASTQ records with reproducible selection when seeded.',
        input => 'Validated FASTQ; standard input is temporarily spooled because sampling needs two passes.',
        output => 'Numbered sampled records in selection order; file output is committed after validation.',
        options => [
            [ '--in, -i FILE', 'Required input FASTQ; use - for standard input.' ],
            [ '--out, -o FILE', 'Required output FASTQ; use - for standard output.' ],
            [ '--quantity, -q N', 'Required positive number of output records.' ],
            [ '--seed N', 'Initialize the random generator reproducibly.' ],
            [ '--without-replacement', 'Select each input position at most once.' ],
        ],
        example => 'perbool fastq sample -i reads.fq.gz -o sample.fq.gz -q 1000 --seed 42 --without-replacement',
    },
    'fastq to-fasta' => {
        usage => 'perbool fastq to-fasta [--in INPUT.fq[.gz]] [--out OUTPUT.fa[.gz]]',
        description => 'Convert validated FASTQ records to canonical two-line FASTA records.',
        input => 'Plain, gzip, or standard-input FASTQ; complete header descriptions are preserved.',
        output => 'FASTA to a plain/gzip file or standard output.',
        options => [
            [ '--in, -i FILE', 'Input FASTQ; default: standard input.' ],
            [ '--out, -o FILE', 'Output FASTA; default: standard output.' ],
        ],
        example => 'perbool fastq to-fasta -i reads.fq.gz -o reads.fa.gz',
    },
    'fastq to-counts' => {
        usage => 'perbool fastq to-counts [--in INPUT.fq[.gz]] [--out COUNTS.tsv[.gz]]',
        description => 'Count identical complete read sequences in a validated FASTQ source.',
        input => 'Plain, gzip, or standard-input FASTQ.',
        output => 'SEQUENCE and COUNT TSV columns sorted lexically by sequence.',
        options => [
            [ '--in, -i FILE', 'Input FASTQ; default: standard input.' ],
            [ '--out, -o FILE', 'Plain/gzip count table; default: standard output.' ],
        ],
        example => 'perbool fastq to-counts -i reads.fq.gz -o sequence-counts.tsv.gz',
    },
    'fastq single-to-paired' => {
        usage => 'perbool fastq single-to-paired --in INPUT.fq[.gz] --length N --r1 R1.fq[.gz] --r2 R2.fq[.gz]',
        description => 'Create synchronized paired-end reads from the two ends of longer single reads.',
        input => 'Validated FASTQ; records shorter than N are skipped.',
        output => 'R1 from the left end and reverse-complemented R2 from the right end, with reversed R2 quality.',
        options => [
            [ '--in, -i FILE', 'Required source FASTQ.' ],
            [ '--length, -l N', 'Required positive length of each generated mate.' ],
            [ '--r1, --R1, -1 FILE', 'Required R1 output path.' ],
            [ '--r2, --R2, -2 FILE', 'Required R2 output path.' ],
        ],
        example => 'perbool fastq single-to-paired -i long.fq.gz -l 100 --r1 R1.fq.gz --r2 R2.fq.gz',
    },
    'qc end-bases' => {
        usage => 'perbool qc end-bases [--in INPUT.fq[.gz]]',
        description => 'Count canonical terminal bases and the total number of validated FASTQ reads.',
        input => 'Plain, gzip, or standard-input FASTQ.',
        output => 'One BASE COUNT row for A, G, C, T, and Total.',
        options => [ [ '--in, -i FILE', 'Input FASTQ; default: standard input.' ] ],
        example => 'perbool qc end-bases -i reads.fq.gz > end-bases.tsv',
    },
    'qc lengths' => {
        usage => 'perbool qc lengths [--in INPUT.fq[.gz]]',
        description => 'Build a numeric read-length distribution from validated FASTQ records.',
        input => 'Plain, gzip, or standard-input FASTQ.',
        output => 'READ_LENGTH and READ_COUNT TSV columns sorted by numeric length.',
        options => [ [ '--in, -i FILE', 'Input FASTQ; default: standard input.' ] ],
        example => 'perbool qc lengths -i reads.fq.gz > lengths.tsv',
    },
    'qc paired-coordinates' => {
        usage => 'perbool qc paired-coordinates --r1 R1.fq[.gz] --r2 R2.fq[.gz]',
        description => 'Identify pairs whose R2 sequence equals R1 or the reverse complement of R1.',
        input => 'Two synchronized validated FASTQ sources; one may be standard input.',
        output => 'Qualifying R1 sequences, emitted only after both complete inputs validate.',
        options => [
            [ '--r1, -1 FILE', 'Required R1 FASTQ.' ],
            [ '--r2, -2 FILE', 'Required R2 FASTQ.' ],
        ],
        example => 'perbool qc paired-coordinates --r1 R1.fq.gz --r2 R2.fq.gz > concordant.txt',
    },
    'qc summary' => {
        usage => 'perbool qc summary [--no-plot] --out-prefix PREFIX INPUT.fq[.gz] ...',
        description => 'Generate a staged set of base, terminal-base, length, and summary QC reports.',
        input => 'One or more validated FASTQ files; at most one may be standard input.',
        output => 'PREFIX_body.tsv, _head.tsv, _tail.tsv, _length.tsv, _summary.tsv, and optionally PREFIX.pdf.',
        options => [
            [ '--out-prefix, -o PREFIX', 'Required destination prefix.' ],
            [ '--no-plot', 'Skip PDF generation and the optional R dependency.' ],
            [ '--rscript PROGRAM', 'Rscript executable name or path.' ],
            [ '--plot-script FILE', 'Use an alternative plotting backend script.' ],
        ],
        example => 'perbool qc summary --no-plot -o qc/sample sample_R1.fq.gz sample_R2.fq.gz',
    },
);

sub _fastq_select_help {
    my $mode = shift;
    my $verb = $mode eq 'fetch' ? 'Retain' : 'Delete';
    my $output_name = $mode eq 'fetch' ? 'selected' : 'retained';
    return {
        usage => "perbool fastq $mode --name NAMES --in INPUT.fq[.gz] --out OUTPUT.fq[.gz]",
        description => "$verb FASTQ records by complete first read ID.",
        input => 'Validated FASTQ plus a plain/gzip ID list containing bare IDs, @ID, or complete headers.',
        output => 'Selected FASTQ records in source order; file output is committed after complete validation.',
        options => [
            [ '--name, -n FILE', 'Required read-ID list; blank lines are ignored.' ],
            [ '--in, -i FILE', 'Required input FASTQ; use - for standard input.' ],
            [ '--out, -o FILE', 'Required plain/gzip output FASTQ; use - for standard output.' ],
        ],
        example => "perbool fastq $mode -n read-ids.txt -i reads.fq.gz -o $output_name.fq.gz",
    };
}

sub has_command_help {
    my ( $group, $command ) = @_;
    return exists $HELP{"$group $command"};
}

sub command_help {
    my ( $group, $command ) = @_;
    my $entry = $HELP{"$group $command"}
      or die "No detailed help for $group $command\n";
    my $text = "Usage:\n  $entry->{usage}\n\n";
    $text .= "Description:\n  $entry->{description}\n\n";
    $text .= "Input:\n  $entry->{input}\n\n";
    $text .= "Output:\n  $entry->{output}\n\n";
    $text .= "Options:\n";
    for my $option ( @{ $entry->{options} } ) {
        $text .= sprintf "  %-30s %s\n", $option->[0], $option->[1];
    }
    $text .= sprintf "  %-30s %s\n", '-h, --help', 'Show this help text.';
    $text .= "\nExample:\n  $entry->{example}\n";
    return $text;
}

1;
