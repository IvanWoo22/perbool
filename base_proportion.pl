#!/usr/bin/env perl
use strict;
use warnings;

my $base = $ARGV[0];
my $prop = $ARGV[1];

sub BASE_PROP {
    my (@SEQ) = @_;
    my ( $A, $G, $C, $T ) = ( 0, 0, 0, 0 );
    foreach (@SEQ) {
        if ( $_ eq "A" ) {
            $A++;
        }
        elsif ( $_ eq "G" ) {
            $G++;
        }
        elsif ( $_ eq "C" ) {
            $C++;
        }
        elsif ( $_ eq "T" ) {
            $T++;
        }
    }
    return (
        $A / ( $A + $G + $C + $T ),
        $G / ( $A + $G + $C + $T ),
        $C / ( $A + $G + $C + $T ),
        $T / ( $A + $G + $C + $T )
    );
}

while (<STDIN>) {
    chomp;
    chomp( my $seq = <STDIN> );
    my %prop;
    ( $prop{"A"}, $prop{"G"}, $prop{"C"}, $prop{"T"} ) =
      BASE_PROP( split( //, $seq ) );
    if ( $prop{$base} > $prop ) {
        print("$_\n$seq\n");
    }
}

__END__
