#!/usr/bin/perl
# It's run after the command line:
#     awk '$3=="exon"||$3=="three_prime_UTR"||$3=="five_prime_UTR" \
#         {print $1 "\t" $4 "\t" $5 "\t" $7 "\t" $9}' \
#         FILE_NAME.gff3

use strict;
use warnings FATAL => 'all';

use AlignDB::IntSpan;

my %trans_range;
my %trans_chr;
my %trans_dir;
while(<STDIN>){
    chomp;
    my ($chr, $start, $end, $dir, $info) = split(/\t/,$_);
    $info =~ /Parent=transcript:([A-Z,a-z,0-9]+])/;
    if(exists($trans_chr{$1})){
        $trans_range{$1}->add_range($start, $end);
    }else{
        $trans_chr{$1} = $chr;
        $trans_dir{$1} = $dir;
        $trans_range{$1} = AlignDB::IntSpan->new();
        $trans_range{$1}->add_range($start, $end);
    }
}

my $index = "ENST00000450305";
my $site = "20";
if($trans_dir{$index} eq "+"){
    my $island = $trans_range{$index}->at($site);
    print("$trans_chr{$index}\t$island\n");
}else{
    my $island = $trans_range{$index}->at(-$site);
    print("$trans_chr{$index}\t$island\n");
}
