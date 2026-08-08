#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Getopt::Long;

use Perbool::Fasta qw(
  extract_interval load_fasta_sequences reverse_complement rna_to_dna
);

=head1 NAME

links2fasta.pl -- Extract FASTA sequences from compact location strings.

=head1 SYNOPSIS

    perl links2fasta.pl --fa genome.fa.gz --in locations.txt

Locations use C<ID:START-END> or C<PREFIX.ID(-):START-END>. Multiple
locations on one line may be separated by tabs. Coordinates are 1-based and
inclusive; output sequences are wrapped at 70 bases.

=cut

Getopt::Long::GetOptions(
    'help|h' => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s' => \my $in_list,
    'fa|f=s' => \my $in_fa,
    'stdin'  => \my $stdin,
) or Getopt::Long::HelpMessage(1);

die "--fa is required\n" unless defined $in_fa;
die "Choose exactly one of --in and --stdin\n"
  unless ( defined($in_list) ? 1 : 0 ) + ( $stdin ? 1 : 0 ) == 1;
die "FASTA and location input cannot both use standard input\n"
  if $in_fa eq '-' && $stdin;

my ($fasta) = load_fasta_sequences($in_fa);
my $location_fh;
if ( defined $in_list ) {
    open $location_fh, '<', $in_list;
}
else {
    $location_fh = *STDIN{IO};
}

my $line_number = 0;
while ( my $line = <$location_fh> ) {
    $line_number++;
    $line =~ s/\r?\n\z//;
    next if $line =~ /^\s*(?:#|\z)/;

    for my $range ( split /\t/, $line ) {
        my ( $id, $start, $end, $strand ) =
          decode_location( $range, $fasta, $line_number );
        my $sequence = extract_interval(
            $fasta->{$id}, $start, $end,
            "FASTA ID '$id' at location line $line_number",
        );
        $sequence = $strand eq '-'
          ? reverse_complement($sequence)
          : rna_to_dna($sequence);

        print ">$range\n";
        while ( length $sequence ) {
            print substr( $sequence, 0, 70, '' ), "\n";
        }
    }
}
close $location_fh if defined $in_list;

sub decode_location {
    my ( $range, $sequences, $source_line ) = @_;
    $range =~ s/^\s+|\s+$//g;
    my ( $raw_id, $strand, $start, $end ) =
      $range =~ /\A(.+?)(?:\(([+-]|-?1)\))?:(\d+)(?:[_-](\d+))?\z/
      or die "Invalid location '$range' at line $source_line\n";
    $end = $start unless defined $end;
    $strand = '+' unless defined $strand;
    $strand = '+' if $strand eq '1';
    $strand = '-' if $strand eq '-1';

    my $id = $raw_id;
    if ( !exists $sequences->{$id} ) {
        my @parts = split /[.]/, $raw_id;
        shift @parts;
        while (@parts) {
            my $candidate = join '.', @parts;
            if ( exists $sequences->{$candidate} ) {
                $id = $candidate;
                last;
            }
            shift @parts;
        }
    }
    die "Unknown FASTA ID '$raw_id' at location line $source_line\n"
      unless exists $sequences->{$id};

    return ( $id, $start, $end, $strand );
}

__END__
