#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Getopt::Long;

use Perbool::Fasta qw(
  extract_interval load_fasta_sequences reverse_complement rna_to_dna
);

=head1 NAME

pick_seq_from_fasta_neo.pl -- Extract 1-based inclusive FASTA intervals.

=head1 SYNOPSIS

    perl pick_seq_from_fasta_neo.pl --fa genome.fa.gz --in intervals.txt
    printf 'chr1 2 10 - feature\n' |
      perl pick_seq_from_fasta_neo.pl --fa genome.fa --stdin

Each nonblank interval line contains C<FASTA_ID START END STRAND [NAME]>.
START and END may be supplied in either order. STRAND must be C<+> or C<->.

=cut

Getopt::Long::GetOptions(
    'help|h' => sub { Getopt::Long::HelpMessage(0) },
    'in|i=s' => \my $in_list,
    'fa|f=s' => \my $in_fa,
    'stdin'  => \my $stdin,
) or Getopt::Long::HelpMessage(1);

die "--fa is required\n" unless defined $in_fa;
die "Choose exactly one of --in and --stdin\n"
  unless ( defined($in_list) ? 1 : 0 ) + ( $stdin ? 1 : 0 ) == 1;
die "FASTA and interval input cannot both use standard input\n"
  if $in_fa eq '-' && $stdin;

my ($fasta) = load_fasta_sequences($in_fa);
my $interval_fh;
if ( defined $in_list ) {
    open $interval_fh, '<', $in_list;
}
else {
    $interval_fh = *STDIN{IO};
}

my $line_number = 0;
while ( my $line = <$interval_fh> ) {
    $line_number++;
    $line =~ s/\r?\n\z//;
    next if $line =~ /^\s*(?:#|\z)/;
    $line =~ s/^\s+|\s+$//g;

    my ( $id, $start, $end, $strand, $name ) = split /\s+/, $line, 5;
    die "Invalid interval at line $line_number: expected ID START END STRAND [NAME]\n"
      unless defined $id && defined $start && defined $end && defined $strand;
    die "Invalid strand '$strand' at interval line $line_number; expected + or -\n"
      unless $strand eq '+' || $strand eq '-';
    die "Unknown FASTA ID '$id' at interval line $line_number\n"
      unless exists $fasta->{$id};

    my $sequence = extract_interval(
        $fasta->{$id}, $start, $end,
        "FASTA ID '$id' at interval line $line_number",
    );
    $sequence = $strand eq '-'
      ? reverse_complement($sequence)
      : rna_to_dna($sequence);

    my $header = ">$id:$start-$end($strand)";
    $header .= $name if defined $name && length $name;
    print "$header\n$sequence\n";
}
close $interval_fh if defined $in_list;

__END__
