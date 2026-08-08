#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/lib";

use Perbool::Fasta qw(
  fasta_iterator open_fasta_reader sequence_text write_fasta_record
);

die "Usage: perl unique_fasta.pl INPUT.fa[.gz]\n" unless @ARGV == 1;
my $input_path = $ARGV[0];
my $fh = open_fasta_reader($input_path);
my $next_record = fasta_iterator($fh);
my %seen_sequence;

while ( my $record = $next_record->() ) {
    my $sequence = sequence_text($record);
    next if $seen_sequence{$sequence}++;
    write_fasta_record( *STDOUT{IO}, $record );
}
close $fh unless $input_path eq '-';

__END__
