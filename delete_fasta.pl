#!/usr/bin/perl
use strict;
use warnings;

open FA, "<", $ARGV[0] or die("$ARGV[0]: $!");
my @info = <FA>;

my @list;
open LS, "<", $ARGV[1] or die("$ARGV[1]: $!");
while (<LS>) {
    chomp;
    push( @list, $_ );
}

open OUT, ">", $ARGV[2];
foreach my $char (@list) {
    my $i = 0;
    my $j = 1;
    while ( $i <= $#info ) {
        if ( $info[$i] =~ /$char/ ) {
            print OUT "$info[$i]";
            until ( $info[ $i + $j ] =~ /^>/ ) {
                print OUT "$info[$i+$j]";
                $j++;
            }
            last;
        }
        else {
            $i++;
        }
    }
    splice @info, $i, $j;
}

foreach (@info) {
    print("$_");
}

__END__
