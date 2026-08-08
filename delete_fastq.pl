#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Getopt::Long;

use Perbool::Fastq qw(
  assert_distinct_paths fastq_id open_fastq_reader open_fastq_writer
  read_fastq_record
  write_fastq_record
);

#---------------#
# GetOpt section
#---------------#

=head1 NAME

delete_fastq.pl -- Delete reads with specified IDs in a FastQ file.

=head1 SYNOPSIS

    perl delete_fastq.pl -n name_list.txt -i input.fq -o output.fq
        Options:
            --help\-h  Brief help message
            --name\-n  The sequences we want to delete
            --in\-i  The FastQ file with path
            --out\-o  The FastQ file with path

=cut

Getopt::Long::GetOptions(
    'help|h'   => sub { Getopt::Long::HelpMessage(0) },
    'name|n=s' => \my $name_list,
    'in|i=s'   => \my $in_fq,
    'out|o=s'  => \my $out_fq,
) or Getopt::Long::HelpMessage(1);

die "--name, --in, and --out are required\n"
  unless defined $name_list && defined $in_fq && defined $out_fq;
assert_distinct_paths( $in_fq, $out_fq );

open( my $name, "<", $name_list );
my %target_name;
while (<$name>) {
    s/\r?\n\z//;
    next unless length;
    s/^@//;
    my ($id) = split /\s+/;
    $target_name{$id} = 1;
}
close $name;

my $in_fh  = open_fastq_reader($in_fq);
my $out_fh = open_fastq_writer($out_fq);

my $record_number = 0;
while ( my $record = read_fastq_record( $in_fh, ++$record_number ) ) {
    unless ( exists $target_name{ fastq_id($record) } ) {
        write_fastq_record( $out_fh, $record );
    }
}
close $in_fh  unless $in_fq  eq '-';
close $out_fh unless $out_fq eq '-';

__END__
