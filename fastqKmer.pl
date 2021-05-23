#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use IO::Zlib;
use Getopt::Long;

sub SPLITSTR {
    my ( $STR, $LENGTH ) = @_;
    my $STRLENGTH = length $STR;
    my @READS;
    for ( my $SEED = 0 ; $SEED + $LENGTH <= $STRLENGTH ; $SEED += 1 ) {
        push @READS, substr( $STR, $SEED, $LENGTH );
    }
    return \@READS;
}

Getopt::Long::GetOptions(
    'help|h'   => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s'   => \my $in_fq,
    'kmer|K=s' => \my $kmer,
    'out|o=s'  => \my $out_fq,
) or Getopt::Long::HelpMessage(1);

my $in_fh;
if ( $in_fq =~ /.gz$/ ) {
    $in_fh = IO::Zlib->new( $in_fq, "rb" );
}
else {
    open( $in_fh, "<", $in_fq );
}

my $out_fh;
if ( $out_fq =~ /.gz$/ ) {
    $out_fh = IO::Zlib->new( $out_fq, "wb9" );
}
else {
    open( $out_fh, ">", $out_fq );
}

while (<$in_fh>) {
    my $qname = $_;
    chomp($qname);
    my $sequence = <$in_fh>;
    chomp($sequence);
    my $t = <$in_fh>;
    chomp($t);
    my $quality = <$in_fh>;
    chomp($quality);

    if ( $kmer <= length($sequence) ) {
        my $seq = SPLITSTR( $sequence, $kmer );
        my $qua = SPLITSTR( $quality,  $kmer );
        foreach my $i ( 0 .. $#{$seq} ) {
            print $out_fh "$qname:$i\n${$seq}[$i]\n$t\n${$qua}[$i]\n";
        }
    }
}

__END__
