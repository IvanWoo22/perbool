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

perl filter_fastq.pl \
    --max 30 --min 20 \
    -i input.fq -o output.fq
    
perl fastqKmer.pl \
    -K 20 \
    -i test.fq -o test.out.fq
    
perl fastq_randomsampling.pl \
    -q 100 \
    -i test.fq -o test.out.fq
```

Each utility is an independent command-line script. Run scripts that support
options with `--help` to see their complete usage.

## Development

Compile-check every Perl script with:

```shell
prove --verbose t
```

The same check runs automatically on GitHub for every push and pull request.

## Author

Ivan Woo <<wuyifanwd@hotmail.com>>

## License

Copyright &copy; 2019 IvanWoo.

Released under the [MIT License](LICENSE).
