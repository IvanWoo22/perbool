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

Getopt::Long::Configure('no_ignore_case');
Getopt::Long::GetOptions(
    'help|h'  => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s'  => \my $in_fq,
    'max|M=i' => \my $max,
    'min|m=i' => \my $min,
    'out|o=s' => \my $out_fq,
) or Getopt::Long::HelpMessage(1);

die "--in and --out are required\n"
  unless defined $in_fq && defined $out_fq;
die "--min and --max must be non-negative\n"
  if ( defined $min && $min < 0 ) || ( defined $max && $max < 0 );
die "--min cannot be greater than --max\n"
  if defined $min && defined $max && $min > $max;

my $in_fh;
if ( $in_fq =~ /[.]gz$/ ) {
    $in_fh = IO::Zlib->new( $in_fq, "rb" )
      or die "Cannot open $in_fq: $!\n";
}
else {
    open( $in_fh, "<", $in_fq );
}

my $out_fh;
if ( $out_fq =~ /[.]gz$/ ) {
    $out_fh = IO::Zlib->new( $out_fq, "wb9" )
      or die "Cannot open $out_fq: $!\n";
}
else {
    open( $out_fh, ">", $out_fq );
}

my $max_length = $max;
my $min_length = defined $min ? $min : 0;

while (<$in_fh>) {
    my $qname    = $_;
    my $sequence = <$in_fh>;
    my $t        = <$in_fh>;
    my $quality  = <$in_fh>;
    die "Truncated FASTQ record after $qname"
      unless defined $sequence && defined $t && defined $quality;

    my $sequence_value = $sequence;
    my $quality_value  = $quality;
    $sequence_value =~ s/\r?\n\z//;
    $quality_value  =~ s/\r?\n\z//;
    die "Sequence and quality lengths differ for $qname"
      unless length($sequence_value) == length($quality_value);

    my $read_length = length($sequence_value);
    if (    ( $min_length <= $read_length )
        and ( !defined $max_length || $max_length >= $read_length ) )
    {
        print $out_fh "$qname$sequence$t$quality";
    }
}

__END__
