#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

sub SEQ_REV_COMP{
    my $temp = reverse shift;
    $temp =~ tr/Uu/Tt/;
    return($temp =~ tr/AGCTagct/TCGAtcga/r);
}

open(FASTA,"<",$ARGV[0]);
open(SEG,"<",$ARGV[1]);

my %fasta;
my $title_name;
while (<FASTA>) {
    if(/^>(\S+)/){
        $title_name = $1;
    }else{
        $_ =~ s/\r?\n//;
        $fasta{$title_name} .= $_;
    }
}
close(FASTA);

while (<SEG>) {
    s/\r?\n//;
    my ($tit, $seg, $dir, $name) = split(/\s+/,$_);
    my ($start, $end) = split(/-/,$seg);

    if ( exists($fasta{$tit}) ) {
        my $length = abs($end - $start) + 1;
        my $seq = substr($fasta{$tit}, $start-1, $length);
        if ($dir eq "-") {
            $seq = SEQ_REV_COMP($seq);
        }
        if(defined($name)){
            print ">$tit:$start-$end($dir)$name\n$seq\n";
        }else{
            print ">$tit:$start-$end($dir)\n$seq\n";
        }

    }else{
        warn("Sorry, there is no such a segment: $_\n");
    }
}
close(SEG);