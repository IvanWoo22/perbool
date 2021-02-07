#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use IO::Zlib;
use Getopt::Long;

=head1 NAME

filter_fastq.pl -- Filter reads with a specific length from FastQ files.

=head1 SYNOPSIS

    perl filter_fastq.pl --max 30 --min 20 -i input.fq -o output.fq
        Options:
            --help\-h Brief help message
            --max\-M  The maximum length of the fragment
            --min\-m  The minimum length of the fragment
            --in\-i   The FastQ file with path
            --out\-o  The FastQ file with path

=cut

Getopt::Long::GetOptions(
    'help|h'  => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s'  => \my $in_fq,
    'max|M=s' => \my $max,
    'min|m=s' => \my $min,
    'out|o=s' => \my $out_fq,
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

my ( $max_length, $min_length ) = ( 1000, 0 );
if ( defined($max) ) {
    $max_length = $max;
}
if ( defined($min) ) {
    $min_length = $min;
}

while (<$in_fh>) {
    my $qname    = $_;
    my $sequence = <$in_fh>;
    my $t        = <$in_fh>;
    my $quality  = <$in_fh>;
    if (    ( $min_length <= length($sequence) )
        and ( $max_length >= length($sequence) ) )
    {
        print $out_fh "$qname$sequence$t$quality";
    }
}

__END__
