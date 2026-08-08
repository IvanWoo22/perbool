#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Getopt::Long;

use Perbool::Fasta qw(
  fasta_id fasta_iterator open_fasta_reader sequence_text write_fasta_record
);

=head1 NAME
fetch_fasta.pl -- Get all sequences with the same searched string in a FastA file.
=head1 SYNOPSIS
    perl fetch_fasta.pl -s protein_coding [options]
        Options:
            --help\-h   Brief help message
            --string\-s Literal text to find in FASTA headers
            --fasta\-f  The FastA file with path
            --stdin     Get FastA from STDIN; mutually exclusive with '--fasta'
            --rna2dna   Change "U" to "T". Default: False
            --exact     Match the complete first FASTA ID. Default: False
=cut

Getopt::Long::GetOptions(
    'help|h'     => sub { Getopt::Long::HelpMessage(0) },
    'string|s=s' => \my $char,
    'fasta|f=s'  => \my $in_fa,
    'stdin'      => \my $stdin,
    'rna2dna'    => \my $rna2dna,
    'exact'      => \my $exact,
) or Getopt::Long::HelpMessage(1);

die "--string is required\n" unless defined $char && length $char;
die "Choose exactly one of --fasta and --stdin\n"
  unless ( defined($in_fa) ? 1 : 0 ) + ( $stdin ? 1 : 0 ) == 1;

my $input_path = defined($in_fa) ? $in_fa : '-';
my $fh = open_fasta_reader($input_path);
my $next_record = fasta_iterator($fh);

while ( my $record = $next_record->() ) {
    my $matches = $exact
      ? fasta_id($record) eq $char
      : index( $record->{header}, $char ) >= 0;
    next unless $matches;

    if ($rna2dna) {
        my $sequence = sequence_text($record);
        $sequence =~ tr/Uu/Tt/;
        $record->{sequence} = $sequence;
    }
    write_fasta_record( *STDOUT{IO}, $record );
}
close $fh unless $input_path eq '-';

__END__
