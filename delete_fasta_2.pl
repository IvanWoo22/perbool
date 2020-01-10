#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

open FA, "<", $ARGV[0] or die("$ARGV[0]: $!");
my @info = <FA>;

open LS, "<", $ARGV[1] or die("$ARGV[1]: $!");
while (<LS>) {
    chomp;
    my ( $i, $j ) = split( /\t/, $_ );
    splice( @info, $i, $j );
}

foreach my $info (@info) {
    print "$info";
}
__END__
