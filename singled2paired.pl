#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use IO::Zlib;
use Getopt::Long;

Getopt::Long::GetOptions(
    'help|h'     => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s'     => \my $in_fq,
    'length|l=s' => \my $length,
    'R1|1=s'     => \my $out_fq1,
    'R2|2=s'     => \my $out_fq2,
) or Getopt::Long::HelpMessage(1);

sub SPLIT_STR {
    my ( $STR, $LENGTH ) = @_;
    my $STR_LENGTH = length $STR;
    my @READS;
    for ( my $SEED = 0 ; $SEED + $LENGTH <= $STR_LENGTH ; $SEED += 1 ) {
        push @READS, substr( $STR, $SEED, $LENGTH );
    }
    return ( $READS[0], $READS[-1] );
}

sub SEQ_REV_COMP {
    my $SEQ = reverse shift;
    $SEQ =~ tr/Uu/Tt/;
    return ( $SEQ =~ tr/AGCTagct/TCGAtcga/r );
}

my $in_fh;
if ( $in_fq =~ /.gz$/ ) {
    $in_fh = IO::Zlib->new( $in_fq, "rb" );
}
else {
    open( $in_fh, "<", $in_fq );
}

my $out_fh1;
if ( $out_fq1 =~ /.gz$/ ) {
    $out_fh1 = IO::Zlib->new( $out_fq1, "wb9" );
}
else {
    open( $out_fh1, ">", $out_fq1 );
}
my $out_fh2;
if ( $out_fq2 =~ /.gz$/ ) {
    $out_fh2 = IO::Zlib->new( $out_fq2, "wb9" );
}
else {
    open( $out_fh2, ">", $out_fq2 );
}

while (<$in_fh>) {
    my $qname = $_;
    chomp($qname);
    my @qntemp   = split( /\s+/, $qname );
    my $sequence = <$in_fh>;
    chomp($sequence);
    my $t = <$in_fh>;
    chomp($t);
    my $quality = <$in_fh>;
    chomp($quality);

    if ( $length <= length($sequence) ) {
        my ( $seq1, $seq2 ) = SPLIT_STR( $sequence, $length );
        my ( $qua1, $qua2 ) = SPLIT_STR( $quality, $length );
        $seq2 = SEQ_REV_COMP($seq2);
        $qua2 = reverse($qua2);
        print $out_fh1 "$qntemp[0] 1 @qntemp[1..$#qntemp]\n$seq1\n$t\n$$qua1\n";
        print $out_fh2 "$qntemp[0] 2 @qntemp[1..$#qntemp]\n$seq2\n$t\n$$qua2\n";

    }
}
