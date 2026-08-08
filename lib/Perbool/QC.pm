package Perbool::QC;

use strict;
use warnings;

use Exporter qw(import);
use Perbool::Fastq qw(open_fastq_reader read_fastq_record sequence_text);

our @EXPORT_OK = qw(summarize_fastq);

sub summarize_fastq {
    my $path = shift;
    my $fh = open_fastq_reader($path);
    my $stats = {
        reads       => 0,
        body        => { map { $_ => 0 } qw(A G C T) },
        head        => { map { $_ => 0 } qw(A G C T) },
        tail        => { map { $_ => 0 } qw(A G C T) },
        length_dist => {},
        min_length  => undef,
        max_length  => undef,
    };

    while ( my $record = read_fastq_record( $fh, $stats->{reads} + 1 ) ) {
        $stats->{reads}++;
        my $sequence = uc sequence_text($record);
        my $length = length $sequence;
        $stats->{length_dist}{$length}++;
        $stats->{min_length} = $length
          if !defined $stats->{min_length} || $length < $stats->{min_length};
        $stats->{max_length} = $length
          if !defined $stats->{max_length} || $length > $stats->{max_length};

        for my $base ( split //, $sequence ) {
            $stats->{body}{$base}++ if exists $stats->{body}{$base};
        }
        if ($length) {
            my $head_base = substr( $sequence, 0, 1 );
            my $tail_base = substr( $sequence, -1, 1 );
            $stats->{head}{$head_base}++ if exists $stats->{head}{$head_base};
            $stats->{tail}{$tail_base}++ if exists $stats->{tail}{$tail_base};
        }
    }
    close $fh unless $path eq '-';
    return $stats;
}

1;
