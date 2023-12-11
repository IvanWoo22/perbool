#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

while (<STDIN>) {
    my @tmp = split "\t";
    $tmp[ $ARGV[0] - 1 ] =~ /$ARGV[1](\w+)/;
    $tmp[ $ARGV[0] - 1 ] = $1;
    print( join( "\t", @tmp ) );
}

__END__
