#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

die "Usage: perl delete_fasta_1.pl INPUT.fa NAMES.txt\n" unless @ARGV == 2;
my ( $fasta_path, $name_path ) = @ARGV;

open my $fasta_fh, '<', $fasta_path;
my @lines = <$fasta_fh>;
close $fasta_fh;

my @headers = grep { $lines[$_] =~ /^>/ } 0 .. $#lines;
open my $name_fh, '<', $name_path;
my %emitted_start;
while ( my $target = <$name_fh> ) {
    $target =~ s/\r?\n\z//;
    next unless length $target;

    my $found;
    for my $start (@headers) {
        next if index( $lines[$start], $target ) < 0;
        my $length = 1;
        $length++
          while $start + $length <= $#lines
          && $lines[ $start + $length ] !~ /^>/;
        print "$start\t$length\n" unless $emitted_start{$start}++;
        $found = 1;
        last;
    }
    warn "No FASTA header contains '$target'\n" unless $found;
}
close $name_fh;

__END__
