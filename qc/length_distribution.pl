#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

my %dist;
while (<STDIN>) {
    chomp( my $seq = <STDIN> );
    readline;
    readline;
    if ( exists( $dist{ length($seq) } ) ) {
        $dist{ length($seq) }++;
    }
    else {
        $dist{ length($seq) } = 1;
    }
}

foreach ( sort { $a <=> $b } keys %dist ) {
    print "$_\t$dist{$_}\n";
}

__END__
