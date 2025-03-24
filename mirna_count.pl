#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';
use IO::Zlib;

sub SEQ_A_PERCENT {
    my $seq   = shift;
    my $count = () = $seq =~ /A/g;
    my $out   = $count / length($seq);
    return ($out);
}

my %read_count;
open( my $COUNT, "<", $ARGV[0] );
while (<$COUNT>) {
    chomp;
    my ( $tmp1, $tmp2 ) = split( /\t/, $_ );
    if ( exists( $read_count{$tmp1} ) ) {
        $read_count{$tmp1} = $read_count{$tmp1} + $tmp2;
    }
    else {
        $read_count{$tmp1} = $tmp2;
    }
}
close($COUNT);

open( my $FA, "<", $ARGV[1] );
while (<$FA>) {
    chomp;
    chomp( my $ref = <$FA> );
    if ( exists( $read_count{$ref} ) ) {
        print("$_\t$read_count{$ref}\t");
        # delete( $read_count{$ref} );
    }
    else {
        print("$_\t0\t");
    }
    my $poly = 0;
    foreach my $seq ( keys(%read_count) ) {
        if ( $seq =~ /^$ref(\S+)/ ) {
            my $tail = $1;
            if ( ( ( length($tail) > 3 ) and ( SEQ_A_PERCENT($tail) >= 0.75 ) )
                or ( $tail eq "AA" )
                or ( $tail eq "AAA" ) )
            {
                $poly += $read_count{$seq};
            }
        }
    }
    print("$poly\n");
}
close($FA);

__END__
