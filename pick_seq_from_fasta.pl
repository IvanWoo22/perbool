#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use autodie;

sub SEQ_REV_COMP{
    my $temp = reverse shift;
    return($temp =~ tr/AGCTagct/TCGAtcga/r);
}

open(FASTA,"<",$ARGV[0]);
open(SEG,"<",$ARGV[1]);

my %fasta;
my $title_name;
while (<FASTA>) {
    if(/^>(.+)$/){
        $title_name = $1;
    }else{
        $_ =~ s/\r?\n//;
        $fasta{$title_name} .= $_;
    }
}
close(FASTA);

while (<SEG>) {
    s/\r?\n//;
    my ($tit, $seg) = split(/\s+/,$_);
    my ($start, $end) = split(/-/,$seg);

    if ( exists($fasta{$tit}) ) {
        my $length = $end - $start + 1;
        if ($length > 0) {
            my $seq = substr($fasta{$tit}, $start-1, $length);
            print ">$tit\n$seq\n";
        }else{
            my $seq = substr($fasta{$tit}, $end-1, -$length);
            $seq = SEQ_REV_COMP($seq);
            print ">$tit\n$seq\n";
        }
    }else{
        warn("Sorry, there is no such a segment: $_\n");
    }
}
close(SEG);