#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use IO::Zlib;
use Getopt::Long;

Getopt::Long::GetOptions(
    'help|h'   => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s'   => \my $in_fq,
    'quantity|q=s' => \my $quantity,
    'out|o=s'  => \my $out_fq,
) or Getopt::Long::HelpMessage(1);

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

my @qname_id;
my %reads;

while (<$in_fh>) {
    my $qname = $_;
    my $sequence = <$in_fh>;
    my $t = <$in_fh>;
    my $quality = <$in_fh>;
    push(@qname_id, $qname);
    $reads{$qname} = "$qname$sequence$t$quality";
}

foreach (1..$quantity){
    print $out_fh "$reads{$qname_id[int(rand($#qname_id))]}";
}

__END__
