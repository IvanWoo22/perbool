#!/usr/bin/env perl
use strict;
use warnings;

open FA, "<", $ARGV[0] or die("$ARGV[0]: $!");
my @info = <FA>;

open LS, "<", $ARGV[1] or die("$ARGV[1]: $!");
while (<LS>) {
    chomp;
    my $char = $_;
    my $i    = 0;
    my $j    = 1;
    while ( $i <= $#info ) {
        if ( $info[$i] =~ /$char/ ) {
            until ( ( $i + $j == $#info ) or ( $info[ $i + $j ] =~ /^>/ ) ) {
                $j++;
            }
            print "$i\t$j\n";
            last;
        }
        else {
            $i++;
        }
    }
}

__END__
