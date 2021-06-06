#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

sub SEQ_REV_COMP {
    my $SEQ = reverse shift;
    $SEQ =~ tr/Uu/Tt/;
    return ( $SEQ =~ tr/AGCTagct/TCGAtcga/r );
}

sub SEQ_TR_TU {
    my $SEQ = shift;
    return ( $SEQ =~ tr/Uu/Tt/r );
}

open( my $FASTA, "<", $ARGV[0] );
open( my $SEG,   "<", $ARGV[1] );

my %fasta;
my $chr_name;
while (<$FASTA>) {
    if (/^>(\S+)/) {
        $chr_name = $1;
    }
    else {
        $_ =~ s/\r?\n//;
        $fasta{$chr_name} .= $_;
    }
}
close($FASTA);

while (<$SEG>) {
    s/\r?\n//;
    my $seq = $_;
    foreach my $chr ( keys(%fasta) ) {
        while ( $fasta{$chr} =~ /$seq/g ) {
            my $p = pos( $fasta{$chr} );
            print "$chr\t$p\n";
        }
    }
}
close($SEG);

__END__
