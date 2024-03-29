#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use IO::Zlib;
use Getopt::Long;

Getopt::Long::GetOptions(
    'help|h'   => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s'   => \my $in_fq,
    'kmer|K=s' => \my $kmer,
    'step|S=s' => \my $step,
    'prefix=s' => \my $prefix,
    'out|o=s'  => \my $out_fq,
) or Getopt::Long::HelpMessage(1);

sub SPLIT_STR {
    my ( $STR, $LENGTH, $STEP ) = @_;
    my $STR_LENGTH = length $STR;
    my ( @READS, $SEED );
    for ( $SEED = 0 ; $SEED + $LENGTH <= $STR_LENGTH ; $SEED += $STEP ) {
        push @READS, substr( $STR, $SEED, $LENGTH );
    }
    unless ( $SEED + $LENGTH == $STR_LENGTH ) {
        push @READS, substr( $STR, $STR_LENGTH - $LENGTH, $LENGTH );
    }
    return \@READS;
}

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

if ( !defined $prefix ) {
    $prefix = "";
}
else {
    $prefix = ":" . $prefix;
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

    if ( $kmer <= length($sequence) ) {
        my $seq = SPLIT_STR( $sequence, $kmer, $step );
        my $qua = SPLIT_STR( $quality,  $kmer, $step );
        foreach my $i ( 0 .. $#{$seq} ) {
            print $out_fh
"$qntemp[0]$prefix\_$i @qntemp[1 .. $#qntemp]\n${$seq}[$i]\n$t\n${$qua}[$i]\n";
        }
    }
}

__END__
