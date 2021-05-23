# **PERBOOL**

## About

As an abbreviation of **PER**L **B**IO T**OOL**S, perbool is a perl toolkit created by Ivan Woo to do some
bioinformatics tasks.

## Usage

```shell
perl fetch_fasta.pl \
    -f mature.fa \
    --string "Spodoptera frugiperda" \
    >sfr_mature.fa
    
cat input.sam | perl 

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

## Author

Ivan Woo <<wuyifanwd@hotmail.com>>

## License

Copyright &copy; 2019 -Iv&alpha;nWoo-

This is a free software; You can redistribute it and/or modify it under the same terms.