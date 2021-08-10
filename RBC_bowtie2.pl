#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

sub SEQ_REV_COMP {
    my $SEQ = reverse shift;
    $SEQ =~ tr/Uu/Tt/;
    return ( $SEQ =~ tr/NAGCTagct/NTCGAtcga/r );
}

sub INDEX_MATCH {
    my $SEQ1    = shift;
    my $SEQ2    = shift;
    my $SEQ1_RC = SEQ_REV_COMP($SEQ1);
    my $SEQ2_RC = SEQ_REV_COMP($SEQ2);
    my $FIND    = shift;
    my $RIND    = shift;
    my @SEQ1    = split( //, $SEQ1 );
    my @SEQ1_RC = split( //, $SEQ1_RC );
    my @SEQ2    = split( //, $SEQ2 );
    my @SEQ2_RC = split( //, $SEQ2_RC );
    my @FIND    = split( //, $FIND );
    my @RIND    = split( //, $RIND );
    my $JUG     = 0;
    my ( $F_MATCH, $R_MATCH ) = ( 0, 0 );

    foreach ( 0 .. 5 ) {
        $F_MATCH++ if $SEQ1[$_] eq $FIND[$_];
        $F_MATCH++ if $SEQ2[$_] eq $RIND[$_];
        $R_MATCH++ if $SEQ2_RC[$_] eq $FIND[$_];
        $R_MATCH++ if $SEQ1_RC[$_] eq $RIND[$_];
    }
    if ( ( $F_MATCH >= 10 ) or ( $R_MATCH >= 10 ) ) {
        $JUG = 1;
    }
    return $JUG;
}

my ( @Findex, @Rindex, @Fin, @Rin );
open( my $IND, "<", $ARGV[0] );
while (<$IND>) {
    chomp;
    my @tmp = split( /\t/, $_ );
    push( @Findex, $tmp[0] );
    push( @Rindex, $tmp[1] );
    push( @Fin,    $#Findex ) if ( $tmp[0] ne 0 );
    push( @Rin,    $#Rindex ) if ( $tmp[1] ne 0 );
}
close($IND);

open( my $COUNT, "<", $ARGV[1] );
my @OUT;
foreach my $id (@Fin) {
    open( $OUT[$id], ">>", $Findex[$id] . $ARGV[1] );
}

while (<$COUNT>) {
    chomp;
    my $string = $_;
    my @tmp1   = split( /\t/, $_ );
    my @tmp2   = split( /_/,  $tmp1[0] );
    print("$tmp2[1]\n");
    foreach my $id (@Fin) {
        if (
            INDEX_MATCH( $tmp2[1], $tmp2[2], $Findex[$id], $Rindex[$id] ) == 1 )
        {
            print { $OUT[$id] } "$string\n";
        }
    }
}
close($COUNT);

__END__
