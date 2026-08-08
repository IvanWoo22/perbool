#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/lib";

use Perbool::Fastq qw(read_fastq_record sequence_text);

my %count;
my $record_number = 0;
while ( my $record = read_fastq_record( *STDIN{IO}, ++$record_number ) ) {
    $count{ sequence_text($record) }++;
}

foreach my $seq ( sort keys %count ) {
    print("$seq\t$count{$seq}\n");
}

__END__
