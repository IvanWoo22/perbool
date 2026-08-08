package Perbool::Command::QcLengths;

use strict;
use warnings;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::QC qw(summarize_fastq);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool qc lengths [--in INPUT.fq[.gz]]
       qc/length_distribution.pl < INPUT.fq

Print READ_LENGTH and READ_COUNT columns sorted by numeric read length. Input
defaults to standard input and gzip files are supported.
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $input_path );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h' => \$help,
        'in|i=s' => \$input_path,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    if (@arguments) {
        die "--in and a positional input cannot be used together\n"
          if defined $input_path;
        die usage_text() unless @arguments == 1;
        $input_path = $arguments[0];
    }
    $input_path = '-' unless defined $input_path;

    my $stats = summarize_fastq($input_path);
    for my $length ( sort { $a <=> $b } keys %{ $stats->{length_dist} } ) {
        print "$length\t$stats->{length_dist}{$length}\n";
    }
    return 0;
}

1;
