#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Getopt::Long;

use Perbool::Fasta qw(load_fasta_sequences);

=head1 NAME

find_seq_from_fasta.pl -- Find literal sequence matches in FASTA records.

=head1 SYNOPSIS

    perl find_seq_from_fasta.pl --fa genome.fa.gz --seq ACGT
    perl find_seq_from_fasta.pl --fa genome.fa --in queries.txt

The output contains the FASTA ID and the 1-based inclusive end coordinate of
each match. Overlapping matches are included.

=cut

Getopt::Long::GetOptions(
    'help|h'  => sub { Getopt::Long::HelpMessage(0) },
    'seq|s=s' => \my $in_seq,
    'in|i=s'  => \my $in_list,
    'fa|f=s'  => \my $in_fa,
    'stdin'   => \my $stdin,
) or Getopt::Long::HelpMessage(1);

die "Choose exactly one of --fa and --stdin\n"
  unless ( defined($in_fa) ? 1 : 0 ) + ( $stdin ? 1 : 0 ) == 1;
die "Choose exactly one of --seq and --in\n"
  unless ( defined($in_seq) ? 1 : 0 ) + ( defined($in_list) ? 1 : 0 ) == 1;

my $fasta_path = defined($in_fa) ? $in_fa : '-';
my ( $fasta, $ids ) = load_fasta_sequences($fasta_path);
my @queries;

if ( defined $in_list ) {
    open my $query_fh, '<', $in_list;
    while ( my $line = <$query_fh> ) {
        $line =~ s/\r?\n\z//;
        next unless length $line;
        push @queries, $line;
    }
    close $query_fh;
}
else {
    push @queries, $in_seq;
}

for my $query (@queries) {
    die "Search sequences must not be empty\n" unless length $query;
    for my $id ( @{$ids} ) {
        my $offset = 0;
        while ( ( $offset = index( $fasta->{$id}, $query, $offset ) ) >= 0 ) {
            my $end_coordinate = $offset + length($query);
            print "$id\t$end_coordinate\n";
            $offset++;
        }
    }
}
__END__
