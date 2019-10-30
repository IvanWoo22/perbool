#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

sub REV_COMP {
    my $SEQ     = shift;
    my $R_C_SEQ = $SEQ =~ tr/AGTCagtc/TCAGtcag/r;
    return $R_C_SEQ;
}

open( my $r1, "<", $ARGV[0] ) or die "Can't open R1: $!";
open( my $r2, "<", $ARGV[1] ) or die "Can't open R2: $!";

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
