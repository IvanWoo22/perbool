package Perbool::Command::TableDuplicateBins;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::IO qw(open_text_reader);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool table count-duplicates [--in LINES.txt.gz]
       count_duplication.pl < LINES.txt

Count distinct complete lines by occurrence-frequency bins. Input defaults to
standard input and blank lines are counted as values.
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
    die "Unexpected arguments: @arguments\n" if @arguments;
    $input_path = '-' unless defined $input_path;

    my %occurrence;
    my $fh = open_text_reader($input_path);
    while ( my $line = <$fh> ) {
        $line =~ s/\r?\n\z//;
        $occurrence{$line}++;
    }
    close $fh unless $input_path eq '-';

    my %bin = map { $_ => 0 } qw(1 2-3 4-5 6-10 11-50 51-100 101-300 >300);
    for my $count ( values %occurrence ) {
        my $label =
            $count == 1   ? '1'
          : $count <= 3   ? '2-3'
          : $count <= 5   ? '4-5'
          : $count <= 10  ? '6-10'
          : $count <= 50  ? '11-50'
          : $count <= 100 ? '51-100'
          : $count <= 300 ? '101-300'
          :                 '>300';
        $bin{$label}++;
    }

    for my $label ( qw(1 2-3 4-5 6-10 11-50 51-100 101-300 >300) ) {
        print "$label:\t$bin{$label}\n";
    }
    return 0;
}

1;
