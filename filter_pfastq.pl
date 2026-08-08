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

Getopt::Long::Configure('no_ignore_case');
Getopt::Long::GetOptions(
    'help|h'  => sub { Getopt::Long::HelpMessage(0) },
    '1=s'     => \my $in_fq1,
    '2=s'     => \my $in_fq2,
    'max|M=i' => \my $max,
    'min|m=i' => \my $min,
    'out|o=s' => \my $out_fq,
    'gzip'    => \my $gzip,
) or Getopt::Long::HelpMessage(1);

die "--1, --2, and --out are required\n"
  unless defined $in_fq1 && defined $in_fq2 && defined $out_fq;
die "--min and --max must be non-negative\n"
  if ( defined $min && $min < 0 ) || ( defined $max && $max < 0 );
die "--min cannot be greater than --max\n"
  if defined $min && defined $max && $min > $max;

my ( $in_fh1, $in_fh2 );
if ( $in_fq1 =~ /[.]gz$/ ) {
    $in_fh1 = IO::Zlib->new( $in_fq1, "rb" )
      or die "Cannot open $in_fq1: $!\n";
}
else {
    open( $in_fh1, "<", $in_fq1 );
}
if ( $in_fq2 =~ /[.]gz$/ ) {
    $in_fh2 = IO::Zlib->new( $in_fq2, "rb" )
      or die "Cannot open $in_fq2: $!\n";
}
else {
    open( $in_fh2, "<", $in_fq2 );
}

my ( $out_fh1, $out_fh2 );
if ( defined($gzip) ) {
    my $out_path1 = $out_fq . "_R1.fq.gz";
    my $out_path2 = $out_fq . "_R2.fq.gz";
    $out_fh1 = IO::Zlib->new( $out_path1, "wb9" )
      or die "Cannot open $out_path1: $!\n";
    $out_fh2 = IO::Zlib->new( $out_path2, "wb9" )
      or die "Cannot open $out_path2: $!\n";
}
else {
    open( $out_fh1, ">", $out_fq . "_R1.fq" );
    open( $out_fh2, ">", $out_fq . "_R2.fq" );
}

my $max_length = $max;
my $min_length = defined $min ? $min : 0;

sub PAIR_ID {
    my $qname = shift;
    my ($id) = split /\s+/, $qname;
    $id =~ s{/([12])$}{};
    return $id;
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

    die "Truncated or unsynchronized paired FASTQ record after $qname1"
      unless defined $sequence1
      && defined $f1
      && defined $quality1
      && defined $qname2
      && defined $sequence2
      && defined $f2
      && defined $quality2;
    die "Paired FASTQ read IDs do not match: $qname1$qname2"
      unless PAIR_ID($qname1) eq PAIR_ID($qname2);

    my $sequence_value1 = $sequence1;
    my $sequence_value2 = $sequence2;
    my $quality_value1  = $quality1;
    my $quality_value2  = $quality2;
    $sequence_value1 =~ s/\r?\n\z//;
    $sequence_value2 =~ s/\r?\n\z//;
    $quality_value1  =~ s/\r?\n\z//;
    $quality_value2  =~ s/\r?\n\z//;
    die "Sequence and quality lengths differ for $qname1"
      unless length($sequence_value1) == length($quality_value1);
    die "Sequence and quality lengths differ for $qname2"
      unless length($sequence_value2) == length($quality_value2);

    my $read_length1 = length($sequence_value1);
    my $read_length2 = length($sequence_value2);

    if (    ( $min_length <= $read_length1 )
        and ( !defined $max_length || $max_length >= $read_length1 )
        and ( $min_length <= $read_length2 )
        and ( !defined $max_length || $max_length >= $read_length2 ) )
    {
        print $out_fh1 "$qname1$sequence1$f1$quality1";
        print $out_fh2 "$qname2$sequence2$f2$quality2";
    }
}

die "Paired FASTQ files contain different numbers of records\n"
  if defined <$in_fh2>;

__END__
