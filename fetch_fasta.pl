#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

use Getopt::Long;

=head1 NAME
fetch_fasta.pl -- Get all sequences with the same searched string in a FastA file.
=head1 SYNOPSIS
    perl fetch_fasta.pl -s protein_coding [options]
        Options:
            --help\-h   Brief help message
            --string\-s The sequences we want to fetch
            --fasta\-f  The FastA file with path
            --stdin     Get FastA from STDIN. It will not been not valid with a provided '--file'
            --rna2dna   Change "U" to "T". Default: False
            --exact     Exact name match. Default: False
=cut

Getopt::Long::GetOptions(
    'help|h'     => sub { Getopt::Long::HelpMessage(0) },
    'string|s=s' => \my $char,
    'fasta|f=s'  => \my $in_fa,
    'stdin'      => \my $stdin,
    'rna2dna'    => \my $rna2dna,
    'exact'      => \my $exact,
) or Getopt::Long::HelpMessage(1);

my @info;
if ( defined($in_fa) ) {
    open my $FA, "<", $in_fa;
    @info = <$FA>;
    close($FA);
}
elsif ( defined($stdin) ) {
    @info = <>;
}
else {
    die("==> You should provide FastA!");
}

sub SEQ_TR_TU {
    my $SEQ = shift;
    return ( $SEQ =~ tr/Uu/Tt/r );
}

my $i = 0;
while ( $i <= $#info ) {
    if ( undef($exact) ) {
        if ( $info[$i] =~ /$char/ ) {
            print( $info[$i] );
            my $j = 1;
            until ( ( $i + $j > $#info ) or ( $info[ $i + $j ] =~ /^>/ ) ) {
                if ( defined($rna2dna) ) {
                    $info[ $i + $j ] = SEQ_TR_TU( $info[ $i + $j ] );
                }
                print( $info[ $i + $j ] );
                $j++;
            }
            $i += $j;
        }
        else {
            $i++;
        }
    }
    else {
        if ( $info[$i] =~ /$char\s+/ ) {
            print( $info[$i] );
            my $j = 1;
            until ( ( $i + $j > $#info ) or ( $info[ $i + $j ] =~ /^>/ ) ) {
                if ( defined($rna2dna) ) {
                    $info[ $i + $j ] = SEQ_TR_TU( $info[ $i + $j ] );
                }
                print( $info[ $i + $j ] );
                $j++;
            }
            $i += $j;
        }
        else {
            $i++;
        }
    }

}

__END__
