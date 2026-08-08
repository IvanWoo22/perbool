#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use IO::Zlib;
use Getopt::Long;

=head1 NAME

fastqKmer.pl -- Split FASTQ reads into fixed-length windows.

=head1 SYNOPSIS

    perl fastqKmer.pl --kmer 20 --step 5 --in input.fq --out output.fq

        Options:
            --help|-h    Brief help message
            --kmer|-K   Window length (required)
            --step|-S   Distance between window starts (default: 1)
            --prefix    Optional suffix added before the window index
            --in|-i     Input FASTQ path
            --out|-o    Output FASTQ path

=cut

Getopt::Long::GetOptions(
    'help|h'   => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s'   => \my $in_fq,
    'kmer|K=i' => \my $kmer,
    'step|S=i' => \my $step,
    'prefix=s' => \my $prefix,
    'out|o=s'  => \my $out_fq,
) or Getopt::Long::HelpMessage(1);

die "--in, --out, and --kmer are required\n"
  unless defined $in_fq && defined $out_fq && defined $kmer;
$step = 1 unless defined $step;
die "--kmer and --step must be positive integers\n"
  unless $kmer > 0 && $step > 0;

sub SPLIT_STR {
    my ( $STR, $LENGTH, $STEP ) = @_;
    my $STR_LENGTH = length $STR;
    my ( @READS, $LAST_SEED );
    for ( my $SEED = 0 ; $SEED + $LENGTH <= $STR_LENGTH ; $SEED += $STEP ) {
        push @READS, substr( $STR, $SEED, $LENGTH );
        $LAST_SEED = $SEED;
    }
    my $TAIL_SEED = $STR_LENGTH - $LENGTH;
    if ( @READS && $LAST_SEED != $TAIL_SEED ) {
        push @READS, substr( $STR, $TAIL_SEED, $LENGTH );
    }
    return \@READS;
}

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

if ( !defined $prefix ) {
    $prefix = "";
}
else {
    $prefix = ":" . $prefix;
}

while (<$in_fh>) {
    my $qname = $_;
    $qname =~ s/\r?\n\z//;
    my @qntemp   = split( /\s+/, $qname );
    my $sequence = <$in_fh>;
    my $t = <$in_fh>;
    my $quality = <$in_fh>;
    die "Truncated FASTQ record after $qname\n"
      unless defined $sequence && defined $t && defined $quality;
    $sequence =~ s/\r?\n\z//;
    $t        =~ s/\r?\n\z//;
    $quality  =~ s/\r?\n\z//;
    die "Sequence and quality lengths differ for $qname\n"
      unless length($sequence) == length($quality);

    if ( $kmer <= length($sequence) ) {
        my $seq = SPLIT_STR( $sequence, $kmer, $step );
        my $qua = SPLIT_STR( $quality,  $kmer, $step );
        foreach my $i ( 0 .. $#{$seq} ) {
            my $new_qname = "$qntemp[0]$prefix\_$i";
            if ( $#qntemp >= 1 ) {
                $new_qname .= " " . join( " ", @qntemp[ 1 .. $#qntemp ] );
            }
            print $out_fh
              "$new_qname\n${$seq}[$i]\n$t\n${$qua}[$i]\n";
        }
    }
}

__END__
