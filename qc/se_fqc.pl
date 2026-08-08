#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Getopt::Long;

use Perbool::Fastq qw(open_fastq_reader read_fastq_record sequence_text);

=head1 NAME

se_fqc.pl -- Summarize base composition and read lengths for FASTQ samples.

=head1 SYNOPSIS

    perl qc/se_fqc.pl [--no-plot] sample1.fq.gz sample2.fq.gz OUTPUT_PREFIX

        Options:
            --help|-h   Brief help message
            --no-plot   Write TSV summaries without invoking the R plot script

=cut

Getopt::Long::GetOptions(
    'help|h'  => sub { Getopt::Long::HelpMessage(0) },
    'no-plot' => \my $no_plot,
) or Getopt::Long::HelpMessage(1);

die "At least one FASTQ input and an output prefix are required\n"
  unless @ARGV >= 2;
my $output_prefix = pop @ARGV;
my @input_paths = @ARGV;

my @stats;
for my $sample_index ( 0 .. $#input_paths ) {
    my $input_path = $input_paths[$sample_index];
    my $in_fh = open_fastq_reader($input_path);
    my $sample = {
        reads       => 0,
        body        => { map { $_ => 0 } qw(A G C T) },
        head        => { map { $_ => 0 } qw(A G C T) },
        tail        => { map { $_ => 0 } qw(A G C T) },
        length_dist => {},
        min_length  => undef,
        max_length  => undef,
    };

    while (
        my $record =
        read_fastq_record( $in_fh, $sample->{reads} + 1 )
      )
    {
        $sample->{reads}++;
        my $sequence = uc sequence_text($record);
        my $length = length($sequence);
        $sample->{length_dist}{$length}++;
        $sample->{min_length} = $length
          if !defined $sample->{min_length}
          || $length < $sample->{min_length};
        $sample->{max_length} = $length
          if !defined $sample->{max_length}
          || $length > $sample->{max_length};

        for my $base ( split //, $sequence ) {
            $sample->{body}{$base}++ if exists $sample->{body}{$base};
        }
        if ($length) {
            my $head_base = substr( $sequence, 0,  1 );
            my $tail_base = substr( $sequence, -1, 1 );
            $sample->{head}{$head_base}++ if exists $sample->{head}{$head_base};
            $sample->{tail}{$tail_base}++ if exists $sample->{tail}{$tail_base};
        }
    }
    close $in_fh unless $input_path eq '-';
    push @stats, $sample;
}

my $body_path   = $output_prefix . '_body.tsv';
my $head_path   = $output_prefix . '_head.tsv';
my $tail_path   = $output_prefix . '_tail.tsv';
my $summary_path = $output_prefix . '_summary.tsv';
my $length_path = $output_prefix . '_length.tsv';

sub WRITE_BASE_TABLE {
    my ( $path, $section ) = @_;
    open my $fh, '>', $path;
    print {$fh} join( "\t", @input_paths ), "\n";
    for my $base (qw(A G C T)) {
        print {$fh} join( "\t", map { $_->{$section}{$base} } @stats ), "\n";
    }
    my @totals =
      $section eq 'body'
      ? map {
        my $sample = $_;
        my $total = 0;
        $total += $sample->{body}{$_} for qw(A G C T);
        $total;
      } @stats
      : map { $_->{reads} } @stats;
    print {$fh} join( "\t", @totals ), "\n";
    close $fh;
}

WRITE_BASE_TABLE( $body_path, 'body' );
WRITE_BASE_TABLE( $head_path, 'head' );
WRITE_BASE_TABLE( $tail_path, 'tail' );

open my $summary_fh, '>', $summary_path;
print {$summary_fh} join( "\t", @input_paths ), "\n";
print {$summary_fh} join( "\t", map { $_->{reads} } @stats ), "\n";
print {$summary_fh} join(
    "\t",
    map {
        defined $_->{min_length}
          ? $_->{min_length} . ' - ' . $_->{max_length}
          : 'NA'
    } @stats
  ),
  "\n";
close $summary_fh;

open my $length_fh, '>', $length_path;
for my $sample_index ( 0 .. $#input_paths ) {
    for my $length (
        sort { $a <=> $b } keys %{ $stats[$sample_index]{length_dist} }
      )
    {
        print {$length_fh} join(
            "\t", $input_paths[$sample_index], $length,
            $stats[$sample_index]{length_dist}{$length}
          ),
          "\n";
    }
}
close $length_fh;

unless ($no_plot) {
    my $pdf_path = $output_prefix . '.pdf';
    my $status = system(
        'Rscript', "$Bin/draw_picture.R", $body_path, $head_path,
        $tail_path, $length_path, $summary_path, $pdf_path,
    );
    die "Failed to run qc/draw_picture.R\n" if $status != 0;
}

__END__
