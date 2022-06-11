#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use Getopt::Long;

Getopt::Long::GetOptions(
    'help|h' => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s' => \my $in_list,
    'fa|f=s' => \my $in_fa,
    'stdin'  => \my $stdin,
) or Getopt::Long::HelpMessage(1);

sub SEQ_REV_COMP {
    my $SEQ = reverse shift;
    $SEQ =~ tr/Uu/Tt/;
    return ( $SEQ =~ tr/AGCTagct/TCGAtcga/r );
}

sub SEQ_TR_TU {
    my $SEQ = shift;
    return ( $SEQ =~ tr/Uu/Tt/r );
}

my %fasta;
my $title_name;
open my $FA, "<", $in_fa;
while (<$FA>) {
    if (/^>(\S+)/) {
        $title_name = $1;
    }
    else {
        $_ =~ s/\r?\n//;
        $fasta{$title_name} .= $_;
    }
}
close($FA);

if ( defined($in_list) ) {
    open( my $SEG, "<", $in_list );
    while (<$SEG>) {
        s/\r?\n//;
        my ( $chr, $start, $end, $dir, $name ) = split( /\s+/, $_ );
        if ( exists( $fasta{$chr} ) ) {
            my $length = abs( $end - $start ) + 1;
            my $seq    = substr( $fasta{$chr}, $start - 1, $length );

            if ( $dir eq "-" ) {
                $seq = SEQ_REV_COMP($seq);
            }
            else {
                $seq = SEQ_TR_TU($seq);
            }

            if ( defined($name) ) {
                print ">$chr:$start-$end($dir)$name\n$seq\n";
            }
            else {
                print ">$chr:$start-$end($dir)\n$seq\n";
            }
        }
        else {
            warn("Sorry, there is no such a segment: $_\n");
        }
    }
    close($SEG);
}
elsif ( defined($stdin) ) {
    while (<>) {
        s/\r?\n//;
        my ( $chr, $start, $end, $dir, $name ) = split( /\s+/, $_ );
        if ( exists( $fasta{$chr} ) ) {
            my $length = abs( $end - $start ) + 1;
            my $seq    = substr( $fasta{$chr}, $start - 1, $length );
            if ( $dir eq "-" ) {
                $seq = SEQ_REV_COMP($seq);
            }
            else {
                $seq = SEQ_TR_TU($seq);
            }
            if ( defined($name) ) {
                print ">$chr:$start-$end($dir)$name\n$seq\n";
            }
            else {
                print ">$chr:$start-$end($dir)\n$seq\n";
            }
        }
        else {
            warn("Sorry, there is no such a segment: $_\n");
        }
    }
}
else {
    die("==> You should provide the FASTA!!\n");
}

__END__
