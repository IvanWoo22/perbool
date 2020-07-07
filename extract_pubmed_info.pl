#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use File::Basename;

my $filedir = dirname(__FILE__);
open( my $IN_FH, "<", $ARGV[0] );
while (<$IN_FH>) {
    chomp;
    system("echo $_ >>$ARGV[2]");
    system(
"Rscript $filedir/extract_pubmed_info/pubmed_data.R $_ $ARGV[1]/$_.tmp.tsv"
    );
    system("cat $ARGV[1]/$_.tmp.tsv >>$ARGV[2]");
    system("echo >>$ARGV[2]");
    system("rm $ARGV[1]/$_.tmp.tsv");
}
close($IN_FH);

__END__
