#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use PerlIO::gzip;

sub REV_COMP {
    my $SEQ     = reverse(shift);
    my $R_C_SEQ = $SEQ =~ tr/AGTCagtc/TCAGtcag/r;
    return $R_C_SEQ;
}

open(my $r1,"<:gzip",$ARGV[0]) or die"$!";
open(my $r2,"<:gzip",$ARGV[1]) or die"$!";

while (<$r1>) {
    chomp( my $seq1 = <$r1> );
    readline($r1);
    readline($r1);
    readline($r2);
    chomp( my $seq2 = <$r2> );
    readline($r2);
    readline($r2);
    my $r_c_seq2 = REV_COMP($seq2);

    if ( ( $seq1 eq $seq2 ) or ( $seq1 eq $r_c_seq2 ) ) {
        print "$seq1\n";
    }
}

close($r1);
close($r2);

__END__
