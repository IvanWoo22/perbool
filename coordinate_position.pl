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
    $info =~ /Parent=transcript:([A-Z,a-z,0-9]+)/;
    if(exists($trans_chr{$1})){
        $trans_range{$1}->add_range($start, $end);
    }else{
        $trans_chr{$1} = $chr;
        $trans_dir{$1} = $dir;
        $trans_range{$1} = AlignDB::IntSpan->new();
        $trans_range{$1}->add_range($start, $end);
    }
}

sub COORDINATE_POS{
    my $index = $_[0];
    my $site = $_[1];
    my $island;
    if($trans_dir{$index} eq "+"){
        $island = $trans_range{$index}->at($site);
    }else{
        $island = $trans_range{$index}->at(-$site);
    }
    my $abs_site = $trans_chr{$index}."\t".$island;
    return($abs_site);
}

open(IN_SAM, "<", $ARGV[0]);

my %exist;
while(<IN_SAM>){
    chomp;
    my ($read_name, $trans_info, $site) = split(/\s+/, $_);
    $trans_info =~ /(ENST[0-9]+)/;
    my $id = $1;
    my $abs_site = COORDINATE_POS($id, $site);
    my $read_abs_site = $read_name."\t".$abs_site;
    unless(exists($exist{$read_abs_site})){
        $exist{$read_abs_site} = 1;
        print("$_\n");
    }
}
close(IN_SAM);

__END__