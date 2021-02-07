#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

while (<STDIN>) {
    $_ =~ s/^@/>/;
    my $seq = <STDIN>;
    readline;
    readline;
    print( $_, $seq );
}

__END__
