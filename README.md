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

```shell
perbool fasta fetch \
    -f mature.fa \
    --string "Spodoptera frugiperda" \
    >sfr_mature.fa

perbool fasta fetch \
    -f transcripts.fa.gz \
    --string transcript_001 --exact \
    >transcript_001.fa

perbool fasta unique input.fa.gz >unique.fa

perbool fasta find \
    --fa genome.fa.gz --seq ACGT

perbool fasta extract-intervals \
    --fa genome.fa.gz --in intervals.txt \
    >intervals.fa

perbool fasta delete \
    --name remove.txt --in input.fa.gz --out retained.fa.gz

perbool fasta substitute \
    --fa reference.fa.gz --in variants.txt \
    >alternate_sequences.fa

perbool fasta filter-composition \
    --base A --fraction-above 0.6 --in input.fa.gz \
    >a_rich.fa

perbool sequence reverse-complement ACGTRYMK

perbool table join sample_a.tsv sample_b.tsv.gz >joined.tsv

perbool table intersect-lines \
    --left expected.txt --right observed.txt --unique

perbool genome bed-to-yaml --in regions.bed.gz >regions.yml

perbool genome transcript-coordinate \
    --transcript ENST00000335137.4 --position 120 \
    --in transcript_ranges.tsv.gz

perbool small-rna tail-counts \
    --counts collapsed_reads.tsv.gz --fasta mature_mirna.fa.gz \
    >mirna_tail_counts.tsv

perbool literature pubmed-search \
    --queries topics.txt --min-year 2015 --retmax 100 \
    --out pubmed_results.txt

perbool fastq filter \
    --max 30 --min 20 \
    -i input.fq -o output.fq
    
perbool fastq split-kmers \
    -K 20 \
    -i test.fq -o test.out.fq
    
perbool fastq sample \
    -q 100 --without-replacement --seed 42 \
    -i test.fq -o test.out.fq

perbool qc summary --no-plot --out-prefix qc/sample \
    sample_R1.fq.gz sample_R2.fq.gz
```

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

Commands with option-based interfaces support `--help`; positional commands
show a concise usage error when invoked without their required arguments.

`bin/perbool` is the stable command namespace. It uses lowercase groups and
kebab-case commands, such as `perbool fasta extract-intervals`. Historical
root-level `.pl` commands remain available as compatibility entry points while
their implementations are migrated.

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
