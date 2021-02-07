#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

use Getopt::Long;

=head1 NAME
list2fasta.pl -- From a list get all sequences in FastA format.
=head1 SYNOPSIS
    perl list2fasta.pl -c int -f list.txt > output.fa
        Options:
            --help\-h   Brief help message
            --sep\-s    The field separator character. Default: "\t"
            --col\-c    The column of sequences
            --file\-f   The list file with path
            --stdin     Get the list from STDIN. It will not been not valid with a provided '--file'
            --rna2dna   Change "U" to "T". Default: False
=cut

Getopt::Long::GetOptions(
    'help|h'   => sub { Getopt::Long::HelpMessage(0) },
    'sep|s=s'  => \my $sep,
    'col|c=s'  => \my $col,
    'file|f=s' => \my $in_list,
    'stdin'    => \my $stdin,
    'rna2dna'  => \my $rna2dna,
) or Getopt::Long::HelpMessage(1);

my @info;
if ( defined($in_list) ) {
    open my $FA, "<", $in_list;
    @info = <$FA>;
    close($FA);
}
elsif ( defined($stdin) ) {
    @info = <>;
}
else {
    die("==> You should provide the list!");
}

unless ( defined($sep) ) {
    $sep = "\t";
}

sub SEQ_TR_TU {
    my $SEQ = shift;
    return ( $SEQ =~ tr/Uu/Tt/r );
}

my %count;
my $i = 0;
while ( $i <= $#info ) {
    my @temp = split( $sep, $info[$i] );
    my $seq  = $temp[ $col - 1 ];
    if ( defined($rna2dna) ) {
        $seq = SEQ_TR_TU($seq);
    }
    if ( exists( $count{$seq} ) ) {
        $count{$seq}++;
    }
    else {
        $count{$seq} = 1;
    }
    $i++;
}

$i = 0;
foreach my $seq ( keys(%count) ) {
    $i++;
    my $length = length($seq);
    print(">seq$i LENGTH=$length REPEAT=$count{$seq}\n$seq\n");
}

__END__
