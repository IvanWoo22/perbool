#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/lib";

use Perbool::Fastq qw(read_fastq_record);

my $record_number = 0;
while ( my $record = read_fastq_record( *STDIN{IO}, ++$record_number ) ) {
    my $header = $record->{header};
    $header =~ s/^@/>/;
    print $header, $record->{sequence};
}

__END__
