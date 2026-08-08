#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Perbool::Fastq qw(read_fastq_record sequence_text);

my %distribution;
my $record_number = 0;
while ( my $record = read_fastq_record( *STDIN{IO}, ++$record_number ) ) {
    $distribution{ length( sequence_text($record) ) }++;
}

for my $length ( sort { $a <=> $b } keys %distribution ) {
    print "$length\t$distribution{$length}\n";
}

__END__
