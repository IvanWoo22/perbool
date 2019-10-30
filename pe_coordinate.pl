#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

sub REV_COMP{
    my $SEQ = shift;
    my $R_C_SEQ = $SEQ =~ tr/AGTCagtc/TCAGtcag/r;
    return $R_C_SEQ;
}

open(R1,"<",$ARGV[0]);
open(R2,"<",$ARGV[1]);

while(<R1>){
    chomp(my $seq1 = <R1>);
    readline R1;
    readline R1;
    readline R2;
    chomp(my $seq2 = <R2>);
    readline R2;
    readline R2;
    my $r_c_seq2 = REV_COMP($seq2);
    if(($seq1 eq $seq2) or ($seq1 eq $r_c_seq2)){
        print "$seq1\n";
    }
}

close R1;
close R2;

__END__