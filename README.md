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

```shell
perl fetch_fasta.pl \
    -f mature.fa \
    --string "Spodoptera frugiperda" \
    >sfr_mature.fa

perl fetch_fasta.pl \
    -f transcripts.fa.gz \
    --string transcript_001 --exact \
    >transcript_001.fa

perl unique_fasta.pl input.fa.gz >unique.fa

perl filter_fastq.pl \
    --max 30 --min 20 \
    -i input.fq -o output.fq
    
perl fastqKmer.pl \
    -K 20 \
    -i test.fq -o test.out.fq
    
perl fastq_randomsampling.pl \
    -q 100 --without-replacement --seed 42 \
    -i test.fq -o test.out.fq
```

`fastq_randomsampling.pl` samples with replacement by default for backward
compatibility. Use `--without-replacement` for conventional FASTQ subsampling
and `--seed` when the sampled dataset must be reproducible.

Each utility is an independent command-line script. Run scripts that support
options with `--help` to see their complete usage.

FASTA readers accept multiline records, and the migrated extraction and
deduplication tools transparently read `.gz` input. `fetch_fasta.pl` searches
header text literally by default; `--exact` instead matches the complete first
ID after `>`.

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
