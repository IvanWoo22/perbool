#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

open( my $fq, "<", $ARGV[0] ) or die "Can't open the file: $!";

my ( $a_count, $g_count, $c_count, $t_count, $total_count ) = ( 0, 0, 0, 0, 0 );
while (<$fq>) {
    chomp( my $seq_string = <$fq> );
    readline($fq);
    readline($fq);
    $total_count++;
    my @seq = split( //, $seq_string );
    if ( $seq[-1] eq "A" ) {
        $a_count++;
    }
    elsif ( $seq[-1] eq "G" ) {
        $g_count++;
    }
    elsif ( $seq[-1] eq "C" ) {
        $c_count++;
    }
    elsif ( $seq[-1] eq "T" ) {
        $t_count++;
    }
}

print(
"A:\t$a_count\nG:\t$g_count\nC:\t$c_count\nT:\t$t_count\nTotal:\t$total_count\n"
);

__END__
