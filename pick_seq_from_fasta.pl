#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($Bin);

die "Usage: perl pick_seq_from_fasta.pl FASTA INTERVALS\n" unless @ARGV == 2;

exec $^X, "$Bin/pick_seq_from_fasta_neo.pl", '--fa', $ARGV[0], '--in', $ARGV[1];
die "Cannot run pick_seq_from_fasta_neo.pl: $!\n";

__END__
