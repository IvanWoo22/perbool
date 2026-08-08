package Perbool::Command::FastaFilterComposition;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fasta qw(
  fasta_iterator open_fasta_reader sequence_text write_fasta_record
);

our @EXPORT_OK = qw(base_fraction run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool fasta filter-composition --base A --fraction-above 0.5 [--in INPUT.fa.gz]
       base_proportion.pl BASE FRACTION < INPUT.fa

Retain records whose selected canonical-base fraction is strictly greater than
FRACTION. The denominator contains A, C, G, and T only; ambiguity symbols do
not contribute. INPUT defaults to standard input.
USAGE
}

sub base_fraction {
    my ( $sequence, $selected_base ) = @_;
    my %count = ( A => 0, C => 0, G => 0, T => 0 );
    for my $base ( split //, uc $sequence ) {
        $count{$base}++ if exists $count{$base};
    }
    my $canonical_total = $count{A} + $count{C} + $count{G} + $count{T};
    return 0 unless $canonical_total;
    return $count{$selected_base} / $canonical_total;
}

sub run {
    my @arguments = @_;
    my ( $help, $base, $fraction, $input_path );

    if ( @arguments == 2 && $arguments[0] !~ /^-/ ) {
        ( $base, $fraction ) = @arguments;
        @arguments = ();
        $input_path = '-';
    }
    else {
        my $options_ok = GetOptionsFromArray(
            \@arguments,
            'help|h'             => \$help,
            'base|b=s'           => \$base,
            'fraction-above|f=s' => \$fraction,
            'in|i=s'             => \$input_path,
        );
        die usage_text() unless $options_ok;
        if ($help) {
            print usage_text();
            return 0;
        }
        die "Unexpected arguments: @arguments\n" if @arguments;
        $input_path = '-' unless defined $input_path;
    }

    $base = uc $base if defined $base;
    die "--base must be one of A, C, G, or T\n"
      unless defined $base && $base =~ /\A[ACGT]\z/;
    die "--fraction-above must be a number from 0 to 1\n"
      unless defined $fraction
      && $fraction =~ /\A(?:0(?:[.]\d*)?|[.]\d+|1(?:[.]0*)?)\z/
      && $fraction >= 0
      && $fraction <= 1;

    my $input_fh = open_fasta_reader($input_path);
    my $next_record = fasta_iterator($input_fh);
    while ( my $record = $next_record->() ) {
        next unless base_fraction( sequence_text($record), $base ) > $fraction;
        write_fasta_record( *STDOUT{IO}, $record );
    }
    close $input_fh unless $input_path eq '-';
    return 0;
}

1;
