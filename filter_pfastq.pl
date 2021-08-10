#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use IO::Zlib;
use Getopt::Long;

=head1 NAME

filter_pfastq.pl -- Filter reads with a specific length from paired FastQ files.

=head1 SYNOPSIS

    perl filter_pfastq.pl --max 30 --min 20 -1 input1.fq -2 input2.fq -o output --gzip
        Options:
            --help\-h Brief help message
            --max\-M  The maximum length of the fragment
            --min\-m  The minimum length of the fragment
            -1   R1 FastQ file with path
            -2   R2 FastQ file with path
            --out\-o  FastQ files prefix with path
            --gzip  Use gzip for output. Default: False

=cut

Getopt::Long::GetOptions(
    'help|h'  => sub { Getopt::Long::HelpMessage(0) },
    '1=s'     => \my $in_fq1,
    '2=s'     => \my $in_fq2,
    'max|M=s' => \my $max,
    'min|m=s' => \my $min,
    'out|o=s' => \my $out_fq,
    'gzip'    => \my $gzip,
) or Getopt::Long::HelpMessage(1);

my ( $in_fh1, $in_fh2 );
if ( $in_fq1 =~ /.gz$/ ) {
    $in_fh1 = IO::Zlib->new( $in_fq1, "rb" );
}
else {
    open( $in_fh1, "<", $in_fq1 );
}
if ( $in_fq2 =~ /.gz$/ ) {
    $in_fh2 = IO::Zlib->new( $in_fq2, "rb" );
}
else {
    open( $in_fh2, "<", $in_fq2 );
}

my ( $out_fh1, $out_fh2 );
if ( defined($gzip) ) {
    $out_fh1 = IO::Zlib->new( $out_fq . "_R1.fq.gz", "wb9" );
    $out_fh2 = IO::Zlib->new( $out_fq . "_R2.fq.gz", "wb9" );
}
else {
    open( $out_fh1, ">", $out_fq . "_R1.fq" );
    open( $out_fh2, ">", $out_fq . "_R2.fq" );
}

my ( $max_length, $min_length ) = ( 1000, 0 );
if ( defined($max) ) {
    $max_length = $max;
}
if ( defined($min) ) {
    $min_length = $min;
}

while (<$in_fh1>) {
    my $qname1    = $_;
    my $sequence1 = <$in_fh1>;
    my $f1        = <$in_fh1>;
    my $quality1  = <$in_fh1>;
    my $qname2    = <$in_fh2>;
    my $sequence2 = <$in_fh2>;
    my $f2        = <$in_fh2>;
    my $quality2  = <$in_fh2>;

    if (    ( $min_length <= length($sequence1) )
        and ( $max_length >= length($sequence1) )
        and ( $min_length <= length($sequence2) )
        and ( $max_length >= length($sequence2) ) )
    {
        print $out_fh1 "$qname1$sequence1$f1$quality1";
        print $out_fh2 "$qname2$sequence2$f2$quality2";
    }
}

__END__
