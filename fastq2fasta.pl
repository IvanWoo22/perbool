#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

while (<STDIN>) {
    $_ =~ s/^@/>/;
    my $seq = <STDIN>;
    readline;
    readline;
    print( $_, $seq );
}

__END__
