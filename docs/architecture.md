# perbool architecture and naming

## Direction

perbool is moving from a flat collection of standalone Perl scripts to a
tested toolkit with one stable command namespace and reusable modules. The
migration is incremental so existing pipelines that invoke historical `.pl`
files continue to work.

## Directory contract

| Path | Responsibility |
| --- | --- |
| `bin/perbool` | Stable user-facing CLI and command dispatch |
| `lib/Perbool/` | Reusable parsing, validation, I/O, CLI, and command logic |
| `t/` | Behavioral regression, compatibility, and compile tests |
| `qc/`, `RBC/` | Domain-specific tools awaiting or undergoing migration |
| root `*.pl` | Temporary compatibility entry points |

New functionality must not introduce another root-level script. Add a
normalized command to `Perbool::CLI`, put reusable logic in a `Perbool::*`
module, and cover the command through `t/`.

Command implementations being migrated live below `lib/Perbool/Command/`;
their historical root scripts contain only argument forwarding and module
loading.

## Naming contract

- CLI groups and commands use lowercase kebab-case: `perbool fastq to-fasta`.
- Perl packages use CamelCase below the `Perbool::` namespace.
- Perl source files match their package names, such as
  `lib/Perbool/Fasta.pm`.
- Test files use lowercase snake_case and end in `.t`.
- Options use long kebab-case names where new options are introduced. Existing
  option aliases remain valid for compatibility.

## Current normalized commands

| Command | Compatibility implementation |
| --- | --- |
| `perbool fasta fetch` | `fetch_fasta.pl` |
| `perbool fasta delete` | `delete_fasta.pl` |
| `perbool fasta unique` | `unique_fasta.pl` |
| `perbool fasta find` | `find_seq_from_fasta.pl` |
| `perbool fasta extract-intervals` | `pick_seq_from_fasta_neo.pl` |
| `perbool fasta extract-locations` | `links2fasta.pl` |
| `perbool fasta from-list` | `list2fasta.pl` |
| `perbool fasta substitute` | `snp4fasta.pl` |
| `perbool fasta filter-composition` | `base_proportion.pl` |
| `perbool sequence reverse-complement` | `rcdna.pl` |
| `perbool table intersect-lines` | `compare_file.pl` |
| `perbool table join` | `tsv_join.pl` |
| `perbool table extract-after` | `format_column_name.pl` |
| `perbool table count-duplicates` | `count_duplication.pl` |
| `perbool genome bed-to-yaml` | `bed2yml.pl` |
| `perbool genome transcript-coordinate` | `coordinate_position.pl` |
| `perbool fastq fetch` | `fetch_fastq.pl` |
| `perbool fastq delete` | `delete_fastq.pl` |
| `perbool fastq filter` | `filter_fastq.pl` |
| `perbool fastq filter-paired` | `filter_pfastq.pl` |
| `perbool fastq split-kmers` | `fastqKmer.pl` |
| `perbool fastq sample` | `fastq_randomsampling.pl` |
| `perbool fastq to-fasta` | `fastq2fasta.pl` |
| `perbool fastq to-counts` | `fastq2count.pl` |
| `perbool fastq single-to-paired` | `singled2paired.pl` |
| `perbool qc end-bases` | `qc/end_base.pl` |
| `perbool qc lengths` | `qc/length_distribution.pl` |
| `perbool qc paired-coordinates` | `qc/pe_coordinate.pl` |
| `perbool qc summary` | `qc/se_fqc.pl` |

The registry in `lib/Perbool/CLI.pm` is authoritative. Its tests verify that
every command name conforms to the naming contract and every mapped
implementation exists.

## Migration stages

1. Add a normalized command without removing its historical entry point.
2. Characterize current behavior with regression tests.
3. Move parsing and domain logic into `lib/Perbool/` modules.
4. Reduce the historical script to a thin compatibility wrapper.
5. Remove a compatibility entry point only in a documented breaking release.

This keeps pipeline compatibility separate from internal architecture: command
names can stabilize now while implementation code is reorganized safely.

`delete_fasta_1.pl` and `delete_fasta_2.pl` are retained only for pipelines
that consume their historical intermediate line-range format. New workflows
should use `perbool fasta delete`, which performs validated ID-based deletion
in one command.

The compatibility name `tsv_join.pl` now follows its stated format: fields are
split only on tabs. Inputs with duplicate keys, empty keys, inconsistent
widths, or no rows fail before output is written. Historical reliance on
space-delimited input must be migrated to explicit TSV first.
