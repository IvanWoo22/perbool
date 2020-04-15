#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

my %count;
while (<STDIN>) {
    chomp( my $seq = <STDIN> );
    readline;
    readline;
    if ( exists( $count{$seq} ) ) {
        $count{$seq}++;
    }
    else {
        $count{$seq} = 1;
    }
}

foreach my $seq ( keys(%count) ) {
    print("$seq\t$count{$seq}\n");
}

__END__