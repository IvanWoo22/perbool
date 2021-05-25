#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use IO::Zlib;
use Getopt::Long;

#---------------#
# GetOpt section
#---------------#

=head1 NAME

fetch_fastq.pl -- Fetch reads with specified IDs in a FastQ file.

=head1 SYNOPSIS

    perl delete_fastq.pl -n name_list.txt -i input.fq -o output.fq
        Options:
            --help\-h  Brief help message
            --name\-n  The sequences we want to fetch
            --in\-i  The FastQ file with path
            --out\-o  The FastQ file with path

=cut

Getopt::Long::GetOptions(
    'help|h'   => sub { Getopt::Long::HelpMessage(0) },
    'name|n=s' => \my $name_list,
    'in|i=s'   => \my $in_fq,
    'out|o=s'  => \my $out_fq,
) or Getopt::Long::HelpMessage(1);

open( my $name, "<", $name_list );
my %target_name;
while (<$name>) {
    chomp;
    $target_name{$_} = 0;
}

my $in_fh;
if ( $in_fq =~ /.gz$/ ) {
    $in_fh = IO::Zlib->new( $in_fq, "rb" );
}
else {
    open( $in_fh, "<", $in_fq );
}

my $out_fh;
if ( $out_fq =~ /.gz$/ ) {
    $out_fh = IO::Zlib->new( $out_fq, "wb9" );
}
else {
    open( $out_fh, ">", $out_fq );
}

while (<$in_fh>) {
    my $qname    = $_;
    my $sequence = <$in_fh>;
    my $t        = <$in_fh>;
    my $quality  = <$in_fh>;
    $qname =~ /^@(\S+)/;
    if ( exists $target_name{$1} ) {
        print $out_fh "$qname$sequence$t$quality";
    }
}

__END__
