#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

sub E19D {
    my $seq = shift;
    my $ind = shift;
    my @st  = split( //, $seq );
    my @ind = split( //, $ind );
    my $jud = 0;
    my $i   = 0;
    foreach ( 0 .. 5 ) {
        $i++ if $st[$_] eq $ind[$_];
    }
    if ( $i >= 5 ) {
        if ( $seq =~ /ACTCTGGATCCCAGAAGGTGA/ ) {
            if ( $seq =~ /TATCAAGGAATTAAGAGAAGCAACATCTCCGAAAGC/ ) {
                $jud = 2;
            }
            elsif (( $seq =~ /TATCAAAATATCTCCGAAAGC/ )
                or ( $seq =~ /TATCAAAACATCTCCGAAAGC/ )
                or ( $seq =~ /TATCAAGACATCTCCGAAAGC/ )
                or ( $seq =~ /TATCAAGGAGCAATCTCCGAAAGC/ )
                or ( $seq =~ /TATCAAGGATCCGAAAGC/ )
                or ( $seq =~ /TATCAAGGAACCATCTCCGAAAGC/ )
                or ( $seq =~ /TATCAAGGAACAGAAAGC/ )
                or ( $seq =~ /TATCAAGGAACAATCTCCGAAAGC/ )
                or ( $seq =~ /TATCAAGGAACCGAAAGC/ )
                or ( $seq =~ /TATCAAGGAACCAACATCTCCGAAAGC/ )
                or ( $seq =~ /TATCAAGGAATCTCCGAAAGC/ )
                or ( $seq =~ /TATCAAGGAAGCAACATCTCCGAAAGC/ )
                or ( $seq =~ /TATCAAGGAATCTCCGAAAGC/ )
                or ( $seq =~ /TATCAAGGAATCGAAAGC/ ) )
            {
                $jud = 1;
            }
        }
    }
    return $jud;
}

sub T790M {
    my $seq = shift;
    my $ind = shift;
    my @st  = split( //, $seq );
    my @ind = split( //, $ind );
    my $jud = 0;
    my $i   = 0;
    foreach ( 0 .. 5 ) {
        $i++ if $st[$_] eq $ind[$_];
    }
    if ( $i >= 5 ) {
        if ( $seq =~ /ATGGCCAGCGTGGACAAC/ ) {
            if ( $seq =~ /CTCATCACGCAGCTC/ ) {
                $jud = 2;
            }
            elsif ( $seq =~ /CTCATCATGCAGCTC/ ) {
                $jud = 1;
            }
        }
    }
    return $jud;
}

sub L858R {
    my $seq = shift;
    my $ind = shift;
    my @st  = split( //, $seq );
    my @ind = split( //, $ind );
    my $jud = 0;
    my $i   = 0;
    foreach ( 0 .. 5 ) {
        $i++ if $st[$_] eq $ind[$_];
    }
    if ( $i >= 5 ) {
        if ( $seq =~ /AGCCAGGAACGTACTGGTGA/ ) {
            if ( $seq =~ /TTTGGGCTGGCCAAA/ ) {
                $jud = 2;
            }
            elsif ( $seq =~ /TTTGGGCGGGCCAAA/ ) {
                $jud = 1;
            }
        }
    }
    return $jud;
}

sub KG12 {
    my $seq = shift;
    my $ind = shift;
    my @st  = split( //, $seq );
    my @ind = split( //, $ind );
    my $jud = 0;
    my $i   = 0;
    foreach ( 0 .. 5 ) {
        $i++ if $st[$_] eq $ind[$_];
    }
    if ( $i >= 5 ) {
        if ( $seq =~ /TAAGGCCTGCTGAAAATGACTG/ ) {
            if ( $seq =~ /TGGAGCTGGTGGCGTA/ ) {
                $jud = 2;
            }
            elsif (( $seq =~ /TGGAGCT[A,C,T]GTGGCGTA/ )
                or ( $seq =~ /TGGAGCTG[C,A,T]TGGCGTA/ )
                or ( $seq =~ /TGGAGCTGGTTGCGTA/ )
                or ( $seq =~ /TGGAGCTGGTGACGTA/ ) )
            {
                $jud = 1;
            }
        }
    }
    return $jud;
}

sub R175H {
    my $seq = shift;
    my $ind = shift;
    my @st  = split( //, $seq );
    my @ind = split( //, $ind );
    my $jud = 0;
    my $i   = 0;
    foreach ( 0 .. 5 ) {
        $i++ if $st[$_] eq $ind[$_];
    }
    if ( $i >= 5 ) {
        if ( $seq =~ /ACCATCGCTATCTGAGCAGC/ ) {
            if ( $seq =~ /GGGGCAGCGCCTCAC/ ) {
                $jud = 2;
            }
            elsif ( $seq =~ /GGGGCAGTGCCTCAC/ ) {
                $jud = 1;
            }
        }
    }
    return $jud;
}

my @E19D_index;
my @T790M_index;
my @L858R_index;
my @KG12_index;
my @R175H_index;
open( my $IND, "<", $ARGV[0] );
while (<$IND>) {
    chomp;
    my @tmp = split( /\t/, $_ );
    push( @E19D_index,  $tmp[0] );
    push( @T790M_index, $tmp[1] );
    push( @L858R_index, $tmp[2] );
    push( @KG12_index,  $tmp[3] );
    push( @R175H_index, $tmp[4] );
}
close($IND);

my (
    @E19D_WT,  @E19D_MU, @T790M_WT, @T790M_MU, @L858R_WT,
    @L858R_MU, @KG12_WT, @KG12_MU,  @R175H_WT, @R175H_MU
);
foreach my $id ( 0 .. $#E19D_index ) {
    $E19D_WT[$id]  = 0;
    $E19D_MU[$id]  = 0;
    $T790M_WT[$id] = 0;
    $T790M_MU[$id] = 0;
    $L858R_WT[$id] = 0;
    $L858R_MU[$id] = 0;
    $KG12_WT[$id]  = 0;
    $KG12_MU[$id]  = 0;
    $R175H_WT[$id] = 0;
    $R175H_MU[$id] = 0;
}

open( my $COUNT, "<", $ARGV[1] );
while (<$COUNT>) {
    chomp;
    my ( $seq, $sum ) = split( /\t/, $_ );
    foreach my $id ( 0 .. $#E19D_index ) {
        my $E19D  = E19D( $seq, $E19D_index[$id] );
        my $T790M = T790M( $seq, $T790M_index[$id] );
        my $L858R = L858R( $seq, $L858R_index[$id] );
        my $KG12  = KG12( $seq, $KG12_index[$id] );
        my $R175H = R175H( $seq, $R175H_index[$id] );
        if ( $E19D == 2 ) {
            $E19D_WT[$id] += $sum;
        }
        elsif ( $E19D == 1 ) {
            $E19D_MU[$id] += $sum;
        }
        if ( $T790M == 2 ) {
            $T790M_WT[$id] += $sum;
        }
        elsif ( $T790M == 1 ) {
            $T790M_MU[$id] += $sum;
        }
        if ( $L858R == 2 ) {
            $L858R_WT[$id] += $sum;
        }
        elsif ( $L858R == 1 ) {
            $L858R_MU[$id] += $sum;
        }
        if ( $KG12 == 2 ) {
            $KG12_WT[$id] += $sum;
        }
        elsif ( $KG12 == 1 ) {
            $KG12_MU[$id] += $sum;
        }
        if ( $R175H == 2 ) {
            $R175H_WT[$id] += $sum;
        }
        elsif ( $R175H == 1 ) {
            $R175H_MU[$id] += $sum;
        }
    }
}

foreach my $id ( 0 .. $#E19D_index ) {
    print("$E19D_WT[$id]\n$E19D_MU[$id]\n");
}
print("\n");
foreach my $id ( 0 .. $#T790M_index ) {
    print("$T790M_WT[$id]\n$T790M_MU[$id]\n");
}
print("\n");
foreach my $id ( 0 .. $#L858R_index ) {
    print("$L858R_WT[$id]\n$L858R_MU[$id]\n");
}
print("\n");
foreach my $id ( 0 .. $#KG12_index ) {
    print("$KG12_WT[$id]\n$KG12_MU[$id]\n");
}
print("\n");
foreach my $id ( 0 .. $#R175H_index ) {
    print("$R175H_WT[$id]\n$R175H_MU[$id]\n");
}
print("\n");

__END__
