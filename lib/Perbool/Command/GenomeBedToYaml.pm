package Perbool::Command::GenomeBedToYaml;

use strict;
use warnings;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::IO qw(open_text_reader);
use Perbool::IntervalSet;

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool genome bed-to-yaml [--in INPUT.bed[.gz]]
       bed2yml.pl INPUT.bed[.gz]

Merge BED intervals by reference name and print a YAML mapping of 1-based,
inclusive run lists. BED input uses the standard 0-based, half-open coordinate
system. Standard input is used when --in is omitted; gzip input is supported.
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

    my $fh = open_text_reader($input_path);
    my %ranges_for;
    my $line_number = 0;
    while ( my $line = <$fh> ) {
        $line_number++;
        $line =~ s/\r?\n\z//;
        next if $line =~ /\A\s*(?:#|\z)/;
        my @fields = split /\t/, $line, -1;
        die "BED $input_path line $line_number must contain at least 3 tab-delimited fields\n"
          unless @fields >= 3;
        my ( $reference, $start, $end ) = @fields[ 0 .. 2 ];
        die "Empty reference name in $input_path at line $line_number\n"
          unless length $reference;
        die "Reference name contains a control character in $input_path at line $line_number\n"
          if $reference =~ /[\x00-\x1f\x7f]/;
        my $set = $ranges_for{$reference} ||= Perbool::IntervalSet->new;
        eval { $set->add_bed_range( $start, $end ) };
        die "Invalid BED interval in $input_path at line $line_number: $@" if $@;
    }
    close $fh unless $input_path eq '-';

    print "---\n";
    for my $reference ( sort keys %ranges_for ) {
        print _yaml_quote($reference), ': ', $ranges_for{$reference}->as_string, "\n";
    }
    return 0;
}

sub _yaml_quote {
    my $value = shift;
    $value =~ s/\\/\\\\/g;
    $value =~ s/"/\\"/g;
    return qq{"$value"};
}

1;
