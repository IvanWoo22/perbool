#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Perbool::Fastq qw(open_fastq_reader read_fastq_record sequence_text);

die "Usage: perl qc/end_base.pl INPUT.fq[.gz]\n" unless @ARGV == 1;
my $input_path = $ARGV[0];
my $in_fh = open_fastq_reader($input_path);

my %base_count = map { $_ => 0 } qw(A G C T);
my $total_count = 0;
while ( my $record = read_fastq_record( $in_fh, $total_count + 1 ) ) {
    $total_count++;
    my $sequence = uc sequence_text($record);
    next unless length $sequence;
    my $end_base = substr( $sequence, -1, 1 );
    $base_count{$end_base}++ if exists $base_count{$end_base};
}
close $in_fh unless $input_path eq '-';

print "A:\t$base_count{A}\n";
print "G:\t$base_count{G}\n";
print "C:\t$base_count{C}\n";
print "T:\t$base_count{T}\n";
print "Total:\t$total_count\n";

__END__
