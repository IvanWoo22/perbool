#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

while (<STDIN>) {
    chomp;
    chomp( my $seq  = <STDIN> );
    chomp( my $tmp1 = <STDIN> );
    chomp( my $tmp2 = <STDIN> );
    if ( $ARGV[0] < length($seq) and length($seq) < $ARGV[1] ) {
        print "$_\n$seq\n$tmp1\n$tmp2\n";
    }
}

__END__
