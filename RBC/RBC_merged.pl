#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

use Getopt::Long;

=head1 NAME
RBC_merged.pl -- Perl script used to handle PCR sequencing data of RBC.
=head1 SYNOPSIS
    perl RBC_merged.pl --index index.txt --count count.file
        Options:
            --help\-h   Brief help message
            --index Index sequences of the samples
            --count   The count file of sample reads
=cut

Getopt::Long::GetOptions(
    'help|h'  => sub { Getopt::Long::HelpMessage(0) },
    'index=s' => \my $ind_file,
    'count=s' => \my $count_file,
) or Getopt::Long::HelpMessage(1);

sub SEQ_REV_COMP {
    my $SEQ = reverse shift;
    $SEQ =~ tr/Uu/Tt/;
    return ( $SEQ =~ tr/NAGCTagct/NTCGAtcga/r );
}

sub REG {
    my $SEQ = shift;
    my %SUB_PATS;
    for my $I ( 0 .. length($SEQ) - 1 ) {
        my $SUB_PAT =
          join( '', substr( $SEQ, 0, $I ), '.', substr( $SEQ, $I + 1 ) );
        $SUB_PATS{$SUB_PAT} = 1;
    }
    my $PAT = join( '|', keys(%SUB_PATS) );
    return ($PAT);
}

sub E19D {
    my $SEQ      = shift;
    my $SEQ_RC   = SEQ_REV_COMP($SEQ);
    my $FIND     = shift;
    my $RIND     = shift;
    my $FIND_REG = REG($FIND);
    my $RIND_REG = REG($RIND);
    my $JUG      = 0;
    if ( ( $SEQ =~ /$FIND_REG/ ) && ( $SEQ =~ /$RIND_REG/ ) ) {
        if ( $SEQ =~ /TATCAAGGAATTAAGAGAAGCAACATCTCCGAAAGC/ ) {
            $JUG = 2;
        }
        elsif (( $SEQ =~ /TATCAAAATATCTCCGAAAGC/ )
            or ( $SEQ =~ /TATCAAAACATCTCCGAAAGC/ )
            or ( $SEQ =~ /TATCAAGACATCTCCGAAAGC/ )
            or ( $SEQ =~ /TATCAAGGAGCAATCTCCGAAAGC/ )
            or ( $SEQ =~ /TATCAAGGATCCGAAAGC/ )
            or ( $SEQ =~ /TATCAAGGAACCATCTCCGAAAGC/ )
            or ( $SEQ =~ /TATCAAGGAACAGAAAGC/ )
            or ( $SEQ =~ /TATCAAGGAACAATCTCCGAAAGC/ )
            or ( $SEQ =~ /TATCAAGGAACCGAAAGC/ )
            or ( $SEQ =~ /TATCAAGGAACCAACATCTCCGAAAGC/ )
            or ( $SEQ =~ /TATCAAGGAATCTCCGAAAGC/ )
            or ( $SEQ =~ /TATCAAGGAAGCAACATCTCCGAAAGC/ )
            or ( $SEQ =~ /TATCAAGGAATCTCCGAAAGC/ )
            or ( $SEQ =~ /TATCAAGGAATCGAAAGC/ ) )
        {
            $JUG = 1;
        }

    }
    elsif ( ( $SEQ_RC =~ /$FIND_REG/ ) && ( $SEQ_RC =~ /$RIND_REG/ ) ) {
        if ( $SEQ_RC =~ /TATCAAGGAATTAAGAGAAGCAACATCTCCGAAAGC/ ) {
            $JUG = 2;
        }
        elsif (( $SEQ_RC =~ /TATCAAAATATCTCCGAAAGC/ )
            or ( $SEQ_RC =~ /TATCAAAACATCTCCGAAAGC/ )
            or ( $SEQ_RC =~ /TATCAAGACATCTCCGAAAGC/ )
            or ( $SEQ_RC =~ /TATCAAGGAGCAATCTCCGAAAGC/ )
            or ( $SEQ_RC =~ /TATCAAGGATCCGAAAGC/ )
            or ( $SEQ_RC =~ /TATCAAGGAACCATCTCCGAAAGC/ )
            or ( $SEQ_RC =~ /TATCAAGGAACAGAAAGC/ )
            or ( $SEQ_RC =~ /TATCAAGGAACAATCTCCGAAAGC/ )
            or ( $SEQ_RC =~ /TATCAAGGAACCGAAAGC/ )
            or ( $SEQ_RC =~ /TATCAAGGAACCAACATCTCCGAAAGC/ )
            or ( $SEQ_RC =~ /TATCAAGGAATCTCCGAAAGC/ )
            or ( $SEQ_RC =~ /TATCAAGGAAGCAACATCTCCGAAAGC/ )
            or ( $SEQ_RC =~ /TATCAAGGAATCTCCGAAAGC/ )
            or ( $SEQ_RC =~ /TATCAAGGAATCGAAAGC/ ) )
        {
            $JUG = 1;
        }
    }
    return $JUG;
}

sub T790M {
    my $SEQ      = shift;
    my $SEQ_RC   = SEQ_REV_COMP($SEQ);
    my $FIND     = shift;
    my $RIND     = shift;
    my $FIND_REG = REG($FIND);
    my $RIND_REG = REG($RIND);
    my $JUG      = 0;
    if ( ( $SEQ =~ /$FIND_REG/ ) && ( $SEQ =~ /$RIND_REG/ ) ) {
        if ( $SEQ =~ /CTCATCACGCAGCTC/ ) {
            $JUG = 2;
        }
        elsif ( $SEQ =~ /CTCATCATGCAGCTC/ ) {
            $JUG = 1;
        }
    }
    elsif ( ( $SEQ_RC =~ /$FIND_REG/ ) && ( $SEQ_RC =~ /$RIND_REG/ ) ) {
        if ( $SEQ_RC =~ /CTCATCACGCAGCTC/ ) {
            $JUG = 2;
        }
        elsif ( $SEQ_RC =~ /CTCATCATGCAGCTC/ ) {
            $JUG = 1;
        }
    }
    return $JUG;
}

sub L858R {
    my $SEQ      = shift;
    my $SEQ_RC   = SEQ_REV_COMP($SEQ);
    my $FIND     = shift;
    my $RIND     = shift;
    my $FIND_REG = REG($FIND);
    my $RIND_REG = REG($RIND);
    my $JUG      = 0;
    if ( ( $SEQ =~ /$FIND_REG/ ) && ( $SEQ =~ /$RIND_REG/ ) ) {
        if ( $SEQ =~ /TTTGGGCTGGCCAAA/ ) {
            $JUG = 2;
        }
        elsif ( $SEQ =~ /TTTGGGCGGGCCAAA/ ) {
            $JUG = 1;
        }
    }
    elsif ( ( $SEQ_RC =~ /$FIND_REG/ ) && ( $SEQ_RC =~ /$RIND_REG/ ) ) {
        if ( $SEQ_RC =~ /TTTGGGCTGGCCAAA/ ) {
            $JUG = 2;
        }
        elsif ( $SEQ_RC =~ /TTTGGGCGGGCCAAA/ ) {
            $JUG = 1;
        }
    }
    return $JUG;
}

sub KG12 {
    my $SEQ      = shift;
    my $SEQ_RC   = SEQ_REV_COMP($SEQ);
    my $FIND     = shift;
    my $RIND     = shift;
    my $FIND_REG = REG($FIND);
    my $RIND_REG = REG($RIND);
    my $JUG      = 0;
    if ( ( $SEQ =~ /$FIND_REG/ ) && ( $SEQ =~ /$RIND_REG/ ) ) {
        if ( $SEQ =~ /TGGAGCTGGTGGCGTA/ ) {
            $JUG = 2;
        }
        elsif (( $SEQ =~ /TGGAGCT[A,C,T]GTGGCGTA/ )
            or ( $SEQ =~ /TGGAGCTG[C,A,T]TGGCGTA/ )
            or ( $SEQ =~ /TGGAGCTGGTTGCGTA/ )
            or ( $SEQ =~ /TGGAGCTGGTGACGTA/ ) )
        {
            $JUG = 1;
        }
    }
    elsif ( ( $SEQ_RC =~ /$FIND_REG/ ) && ( $SEQ_RC =~ /$RIND_REG/ ) ) {
        if ( $SEQ_RC =~ /TGGAGCTGGTGGCGTA/ ) {
            $JUG = 2;
        }
        elsif (( $SEQ_RC =~ /TGGAGCT[A,C,T]GTGGCGTA/ )
            or ( $SEQ_RC =~ /TGGAGCTG[C,A,T]TGGCGTA/ )
            or ( $SEQ_RC =~ /TGGAGCTGGTTGCGTA/ )
            or ( $SEQ_RC =~ /TGGAGCTGGTGACGTA/ ) )
        {
            $JUG = 1;
        }
    }
    return $JUG;
}

sub R175H {
    my $SEQ      = shift;
    my $SEQ_RC   = SEQ_REV_COMP($SEQ);
    my $FIND     = shift;
    my $RIND     = shift;
    my $FIND_REG = REG($FIND);
    my $RIND_REG = REG($RIND);
    my $JUG      = 0;
    if ( ( $SEQ =~ /$FIND_REG/ ) && ( $SEQ =~ /$RIND_REG/ ) ) {
        if ( $SEQ =~ /GTGAGGCGCTGCCCCC/ ) {
            $JUG = 2;
        }
        elsif ( $SEQ =~ /GTGAGGCACTGCCCCC/ ) {
            $JUG = 1;
        }
    }
    elsif ( ( $SEQ_RC =~ /$FIND_REG/ ) && ( $SEQ_RC =~ /$RIND_REG/ ) ) {
        if ( $SEQ_RC =~ /GTGAGGCGCTGCCCCC/ ) {
            $JUG = 2;
        }
        elsif ( $SEQ_RC =~ /GTGAGGCACTGCCCCC/ ) {
            $JUG = 1;
        }
    }
    return $JUG;
}

my ( @Findex, @Rindex, @Fin, @Rin );
open( my $IND, "<", $ind_file );
while (<$IND>) {
    chomp;
    my @tmp = split( /\t/, $_ );
    push( @Findex, $tmp[0] );
    push( @Rindex, $tmp[1] );
    push( @Fin,    $#Findex ) if ( $tmp[0] ne 0 );
    push( @Rin,    $#Rindex ) if ( $tmp[1] ne 0 );
}
close($IND);

my (
    @E19D_WT,  @E19D_MU, @T790M_WT, @T790M_MU, @L858R_WT,
    @L858R_MU, @KG12_WT, @KG12_MU,  @R175H_WT, @R175H_MU
);
foreach my $id ( 0 .. $#Findex ) {
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

open( my $COUNT, "<", $count_file );
while (<$COUNT>) {
    chomp;
    my ( $seq, $sum ) = split( /\t/, $_ );
    foreach my $id (@Fin) {
        my $E19D = E19D( $seq, $Findex[$id], $Rindex[$id] );
        if ( $E19D == 2 ) {
            $E19D_WT[$id] += $sum;
        }
        elsif ( $E19D == 1 ) {
            $E19D_MU[$id] += $sum;
        }

        my $T790M = T790M( $seq, $Findex[$id], $Rindex[$id] );
        if ( $T790M == 2 ) {
            $T790M_WT[$id] += $sum;
        }
        elsif ( $T790M == 1 ) {
            $T790M_MU[$id] += $sum;
        }

        my $L858R = L858R( $seq, $Findex[$id], $Rindex[$id] );
        if ( $L858R == 2 ) {
            $L858R_WT[$id] += $sum;
        }
        elsif ( $L858R == 1 ) {
            $L858R_MU[$id] += $sum;
        }

        my $KG12 = KG12( $seq, $Findex[$id], $Rindex[$id] );
        if ( $KG12 == 2 ) {
            $KG12_WT[$id] += $sum;
        }
        elsif ( $KG12 == 1 ) {
            $KG12_MU[$id] += $sum;
        }

        my $R175H = R175H( $seq, $Findex[$id], $Rindex[$id] );
        if ( $R175H == 2 ) {
            $R175H_WT[$id] += $sum;
        }
        elsif ( $R175H == 1 ) {
            $R175H_MU[$id] += $sum;
        }
    }
}
close($COUNT);

foreach my $id ( 0 .. $#Findex ) {
    my $prop;
    if ( $E19D_WT[$id] + $E19D_MU[$id] > 0 ) {
        $prop = sprintf( "%.4f",
            $E19D_MU[$id] / ( $E19D_WT[$id] + $E19D_MU[$id] ) * 100 );
    }
    else {
        $prop = 0;
    }
    print("$E19D_WT[$id]\n$E19D_MU[$id]\n$prop%\n");
}
print("\n");
foreach my $id ( 0 .. $#Findex ) {
    my $prop;
    if ( $T790M_WT[$id] + $T790M_MU[$id] > 0 ) {
        $prop = sprintf( "%.4f",
            $T790M_MU[$id] / ( $T790M_WT[$id] + $T790M_MU[$id] ) * 100 );
    }
    else {
        $prop = 0;
    }
    print("$T790M_WT[$id]\n$T790M_MU[$id]\n$prop%\n");
}
print("\n");
foreach my $id ( 0 .. $#Findex ) {
    my $prop;
    if ( $L858R_WT[$id] + $L858R_MU[$id] > 0 ) {
        $prop = sprintf( "%.4f",
            $L858R_MU[$id] / ( $L858R_WT[$id] + $L858R_MU[$id] ) * 100 );
    }
    else {
        $prop = 0;
    }
    print("$L858R_WT[$id]\n$L858R_MU[$id]\n$prop%\n");
}
print("\n");
foreach my $id ( 0 .. $#Findex ) {
    my $prop;
    if ( $KG12_WT[$id] + $KG12_MU[$id] > 0 ) {
        $prop = sprintf( "%.4f",
            $KG12_MU[$id] / ( $KG12_WT[$id] + $KG12_MU[$id] ) * 100 );
    }
    else {
        $prop = 0;
    }
    print("$KG12_WT[$id]\n$KG12_MU[$id]\n$prop%\n");
}
print("\n");
foreach my $id ( 0 .. $#Findex ) {
    my $prop;
    if ( $R175H_WT[$id] + $R175H_MU[$id] > 0 ) {
        $prop = sprintf( "%.4f",
            $R175H_MU[$id] / ( $R175H_WT[$id] + $R175H_MU[$id] ) * 100 );
    }
    else {
        $prop = 0;
    }
    print("$R175H_WT[$id]\n$R175H_MU[$id]\n$prop%\n");
}
print("\n\n");

__END__
