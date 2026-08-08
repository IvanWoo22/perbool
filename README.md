# PERBOOL

## About

As an abbreviation of **PER**L **B**IO T**OOL**S, perbool is a collection of
small Perl utilities for common bioinformatics tasks, including FASTA/FASTQ
processing, sequence extraction, read counting, and quality-control summaries.

## Requirements

- Perl 5.14 or newer
- [`cpanm`](https://metacpan.org/pod/App::cpanminus) for dependency installation
- R packages `RISmed`, `gridExtra`, and `ggpubr` for the optional R scripts

Install the Perl dependencies declared in `cpanfile`:

```shell
cpanm --installdeps .
```

## Usage

Use the normalized repository-local CLI:

```shell
export PATH="$PWD/bin:$PATH"
perbool --help
```

Every normalized command has a detailed help page describing its inputs,
outputs, options, defaults, validation behavior, and a runnable example:

```shell
perbool help fasta fetch
perbool fasta fetch --help
```

Plain and gzip files are selected by filename suffix. Where documented, `-`
means standard input or output. File outputs that use staged validation replace
their destination only after all relevant input has been checked successfully.

### FASTA commands

| Command | What it does | Example |
| --- | --- | --- |
| `fasta fetch` | Select records by literal header text or exact first ID. | `perbool fasta fetch -f transcripts.fa.gz -s transcript_001 --exact -o hit.fa` |
| `fasta delete` | Remove records whose first IDs occur in a name list. | `perbool fasta delete -n remove.txt -i input.fa.gz -o retained.fa.gz` |
| `fasta unique` | Keep the first record for each distinct complete sequence. | `perbool fasta unique -i input.fa.gz -o unique.fa.gz` |
| `fasta find` | Report every overlapping literal sequence match and its 1-based end coordinate. | `perbool fasta find -f genome.fa.gz -s ACGT -o matches.tsv` |
| `fasta extract-intervals` | Extract strand-aware `ID START END STRAND [NAME]` intervals. | `perbool fasta extract-intervals -f genome.fa.gz -i intervals.tsv -o intervals.fa` |
| `fasta extract-locations` | Extract compact `ID:START-END` location strings. | `perbool fasta extract-locations -f genome.fa.gz -i locations.txt -o regions.fa` |
| `fasta from-list` | Count sequences in a selected table column and emit counted FASTA. | `perbool fasta from-list --file reads.tsv --col 2 --rna2dna >collapsed.fa` |
| `fasta substitute` | Apply each validated `ID POSITION REF ALT` substitution independently. | `perbool fasta substitute -f reference.fa.gz -i variants.tsv >alternates.fa` |
| `fasta filter-composition` | Retain records strictly above a canonical-base fraction. | `perbool fasta filter-composition -b A -f 0.6 -i input.fa.gz >a-rich.fa` |

### Sequence commands

| Command | What it does | Example |
| --- | --- | --- |
| `sequence reverse-complement` | Reverse-complement DNA/RNA with IUPAC ambiguity symbols. | `perbool sequence reverse-complement ACGTRYMK` |

### Table commands

| Command | What it does | Example |
| --- | --- | --- |
| `table intersect-lines` | Filter the right file to exact lines also found in the left file. | `perbool table intersect-lines -l expected.txt -r observed.txt --unique` |
| `table join` | Full-outer join TSV files on their first column. | `perbool table join sample-a.tsv sample-b.tsv.gz >joined.tsv` |
| `table extract-after` | Replace one TSV field with the word suffix after a literal prefix. | `perbool table extract-after -c 2 -p ID= -i attributes.tsv >ids.tsv` |
| `table count-duplicates` | Count how many distinct lines occur at each frequency. | `perbool table count-duplicates -i barcodes.txt.gz >frequency.tsv` |

### Genome commands

| Command | What it does | Example |
| --- | --- | --- |
| `genome bed-to-yaml` | Merge BED intervals and emit 1-based inclusive YAML run lists. | `perbool genome bed-to-yaml -i regions.bed.gz >regions.yml` |
| `genome transcript-coordinate` | Map a transcript-relative position to a genomic coordinate. | `perbool genome transcript-coordinate -t ENST00000335137.4 -p 120 -i ranges.tsv.gz` |

### Small-RNA and literature commands

| Command | What it does | Example |
| --- | --- | --- |
| `small-rna tail-counts` | Count exact and qualifying poly(A)-tailed reads per reference. | `perbool small-rna tail-counts -c reads.tsv.gz -f mature.fa.gz >tails.tsv` |
| `literature pubmed-search` | Run a validated RISmed PubMed query batch. | `perbool literature pubmed-search -q topics.txt --min-year 2020 -o results.txt` |

### FASTQ commands

| Command | What it does | Example |
| --- | --- | --- |
| `fastq fetch` | Retain reads whose complete first IDs occur in a list. | `perbool fastq fetch -n ids.txt -i reads.fq.gz -o selected.fq.gz` |
| `fastq delete` | Remove reads whose complete first IDs occur in a list. | `perbool fastq delete -n ids.txt -i reads.fq.gz -o retained.fq.gz` |
| `fastq filter` | Filter single-end reads by inclusive length bounds. | `perbool fastq filter -i reads.fq.gz -o kept.fq.gz -m 20 -M 30` |
| `fastq filter-paired` | Keep synchronized pairs when both mates satisfy length bounds. | `perbool fastq filter-paired --r1 R1.fq.gz --r2 R2.fq.gz -o kept --gzip` |
| `fastq split-kmers` | Split reads and qualities into fixed-length windows. | `perbool fastq split-kmers -i reads.fq.gz -o windows.fq.gz -K 20 -S 5` |
| `fastq sample` | Randomly sample complete records, optionally without replacement. | `perbool fastq sample -i reads.fq.gz -o sample.fq.gz -q 1000 --seed 42 --without-replacement` |
| `fastq to-fasta` | Convert validated FASTQ records to two-line FASTA. | `perbool fastq to-fasta -i reads.fq.gz -o reads.fa.gz` |
| `fastq to-counts` | Count identical read sequences and emit sorted TSV. | `perbool fastq to-counts -i reads.fq.gz -o counts.tsv.gz` |
| `fastq single-to-paired` | Create R1/R2 reads from the two ends of longer reads. | `perbool fastq single-to-paired -i long.fq.gz -l 100 --r1 R1.fq.gz --r2 R2.fq.gz` |

### QC commands

| Command | What it does | Example |
| --- | --- | --- |
| `qc end-bases` | Count terminal A/G/C/T bases and total reads. | `perbool qc end-bases -i reads.fq.gz >end-bases.tsv` |
| `qc lengths` | Produce a numeric FASTQ read-length distribution. | `perbool qc lengths -i reads.fq.gz >lengths.tsv` |
| `qc paired-coordinates` | Find pairs whose sequences are identical or reverse complements. | `perbool qc paired-coordinates --r1 R1.fq.gz --r2 R2.fq.gz >concordant.txt` |
| `qc summary` | Build staged TSV QC reports and an optional PDF. | `perbool qc summary --no-plot -o qc/sample sample_R1.fq.gz sample_R2.fq.gz` |

`perbool fastq sample` (legacy entry point: `fastq_randomsampling.pl`) samples
with replacement by default for backward compatibility. Use
`--without-replacement` for conventional FASTQ subsampling and `--seed` when
the sampled dataset must be reproducible. File, gzip, and standard input are
supported; standard input is validated into a temporary spool for the second
sampling pass.

The maintained FASTQ conversion, selection, and length-filter commands accept
gzip input and output through their normalized `--in`/`--out` interfaces.
File outputs are written in the destination directory and committed only after
the complete input validates; malformed later records or paired-ID mismatches
therefore preserve existing results. `fastq filter-paired` accepts normalized
`--r1` and `--r2` options while retaining legacy `-1` and `-2` aliases.
The same validated-output behavior covers `split-kmers`, `sample`, and
`single-to-paired`; the latter accepts normalized `--r1`/`--r2` names while
retaining `--R1`/`--R2` and `-1`/`-2` compatibility aliases.

Normalized FASTA commands accept `--out` for validated plain or gzip file
output while retaining standard output as the default. Query, interval, and
compact-location lists also support gzip input. Existing output files are left
unchanged when a malformed later FASTA record, interval, or location is found.

Every normalized command supports both `perbool GROUP COMMAND --help` and
`perbool help GROUP COMMAND`, including commands that retain positional
compatibility forms.

`bin/perbool` is the stable command namespace. It uses lowercase groups and
kebab-case commands, such as `perbool fasta extract-intervals`. Historical
root-level `.pl` commands remain available as compatibility entry points; all
registered command logic now lives in `lib/Perbool/Command/` modules.

FASTA readers accept multiline records, and the migrated extraction and
deduplication tools transparently read `.gz` input. `fetch_fasta.pl` searches
header text literally by default; `--exact` instead matches the complete first
ID after `>`.

`find_seq_from_fasta.pl` reports the FASTA ID and 1-based inclusive end
coordinate for every literal match, including overlaps, in FASTA record order.
Interval files for `pick_seq_from_fasta_neo.pl` contain
`FASTA_ID START END STRAND [NAME]`; coordinates are 1-based and inclusive,
either coordinate order is accepted, and invalid or out-of-range intervals are
rejected instead of silently truncated. The older two-argument
`pick_seq_from_fasta.pl` command remains available as a compatibility wrapper.

`perbool fasta substitute` consumes `FASTA_ID POSITION REF ALT` rows, validates
the complete batch before writing, and emits one independent alternate record
per row. `perbool fasta filter-composition` uses canonical A/C/G/T bases as its
denominator and ignores ambiguity symbols. Its threshold comparison is strict
(`fraction > threshold`).

The `table` command group operates on exact text or tab-delimited data. In
particular, `perbool table join` performs a sorted full-outer join on the first
column, preserves empty cells, and rejects duplicate keys or inconsistent
column counts instead of silently overwriting data.

`perbool genome bed-to-yaml` reads standard BED coordinates (0-based,
half-open), merges intervals by reference name, and writes 1-based inclusive
run lists. This corrects the historical `bed2yml.pl` off-by-one behavior, which
passed BED columns directly to an inclusive interval API.

`perbool genome transcript-coordinate` maps a 1-based position along the union
of supplied exon/UTR ranges to its genomic coordinate. Its five-column input is
`REFERENCE START END STRAND GFF_ATTRIBUTES`; coordinates are 1-based inclusive,
negative-strand transcripts are traversed from high to low genomic coordinate,
and comma-separated `Parent=transcript:ID` values are supported.

`perbool small-rna tail-counts` reports the exact read count and poly(A)-tailed
read count for each FASTA reference. It accepts multiline or gzip FASTA and
count tables, merges duplicate read-sequence rows case-insensitively, and uses
literal prefix matching. The output retains the historical three-column form:
complete FASTA header, exact count, and poly(A)-tail count.

`perbool literature pubmed-search` runs the bundled RISmed backend without
passing query text through a shell. Blank query lines are ignored, the search
year range and result limit are configurable, and the maximum year defaults to
the current year. All searches must succeed before the output file is opened,
so a failed batch preserves any existing result. `RISmed` and `Rscript` are
required only for this optional command.

The `qc` command group shares one validated FASTQ statistics implementation.
`qc end-bases` and `qc lengths` accept `--in`, while
`qc paired-coordinates` accepts `--r1` and `--r2`. `qc summary` stages all TSV
and optional PDF outputs before replacing final files, so malformed FASTQ or a
failed plot backend does not leave a partially updated report set.

## Project layout

- `bin/perbool`: normalized user-facing command entry point
- `lib/Perbool/`: reusable parsing, validation, I/O, path, CLI, and command modules
- `t/`: behavioral regression and compile tests
- `qc/`: compatibility entry points and the optional QC plotting backend
- root-level `.pl` files: compatibility entry points; new tools should not be
  added here

See [the CLI and directory migration guide](docs/architecture.md) for naming
rules, current command mappings, and the staged refactoring policy.
Project-specific RBC code was removed without modification after archival; see
[the non-tool archive manifest](docs/non-tool-archive.md) for its recovery
branch and verified tree hashes.

## Development

Run the complete regression and compile-check suite with:

```shell
prove --verbose t
```

The same check runs automatically on GitHub for every push and pull request.

## Author

Ivan Woo <<wuyifanwd@hotmail.com>>

## License

Copyright &copy; 2019 IvanWoo.

Released under the [MIT License](LICENSE).
