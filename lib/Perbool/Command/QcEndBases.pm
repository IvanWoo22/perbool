package Perbool::Command::QcEndBases;

use strict;
use warnings;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::QC qw(summarize_fastq);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool qc end-bases [--in INPUT.fq[.gz]]
       qc/end_base.pl INPUT.fq[.gz]

Count canonical A/G/C/T terminal bases and the total number of FASTQ reads.
Input defaults to standard input for the normalized command.
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
    print "$_:\t$stats->{tail}{$_}\n" for qw(A G C T);
    print "Total:\t$stats->{reads}\n";
    return 0;
}

1;
