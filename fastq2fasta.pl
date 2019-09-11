#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

while(<STDIN>){
    $_ =~ s/^@/>/;
    my ($seq, undef,undef) = <STDIN>;
    print($_,$seq);
}