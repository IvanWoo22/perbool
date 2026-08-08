#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

die "Usage: perl delete_fasta_2.pl INPUT.fa RANGES.tsv\n" unless @ARGV == 2;
my ( $fasta_path, $range_path ) = @ARGV;

open my $fasta_fh, '<', $fasta_path;
my @lines = <$fasta_fh>;
close $fasta_fh;

open my $range_fh, '<', $range_path;
my @ranges;
my %seen_range;
my $line_number = 0;
while ( my $line = <$range_fh> ) {
    $line_number++;
    $line =~ s/\r?\n\z//;
    next unless length $line;
    my ( $start, $length, @extra ) = split /\t/, $line;
    die "Invalid deletion range at line $line_number\n"
      unless defined $start
      && defined $length
      && !@extra
      && $start =~ /\A\d+\z/
      && $length =~ /\A[1-9]\d*\z/
      && $start + $length <= @lines;
    push @ranges, [ $start, $length ] unless $seen_range{"$start\t$length"}++;
}
close $range_fh;

@ranges = sort { $b->[0] <=> $a->[0] } @ranges;
my $previous_start = scalar @lines;
for my $range (@ranges) {
    my ( $start, $length ) = @{$range};
    die "Overlapping deletion ranges include line index $start\n"
      if $start + $length > $previous_start;
    splice @lines, $start, $length;
    $previous_start = $start;
}
print @lines;

__END__
