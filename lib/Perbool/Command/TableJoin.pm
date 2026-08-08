package Perbool::Command::TableJoin;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::IO qw(open_text_reader);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool table join [--missing TEXT] TABLE1.tsv [TABLE2.tsv ...]
       tsv_join.pl TABLE1.tsv [TABLE2.tsv ...]

Full-outer join tab-delimited tables on the first column. Every input must have
a consistent width and unique, nonempty keys. Missing value cells default to
NA. Gzip input is supported; at most one input may be standard input (-).
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $missing );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'      => \$help,
        'missing|m=s' => \$missing,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    die "At least one input table is required\n" unless @arguments;
    $missing = 'NA' unless defined $missing;
    die "--missing must not contain tabs or newlines\n"
      if $missing =~ /[\t\r\n]/;
    my $stdin_count = grep { $_ eq '-' } @arguments;
    die "Only one input table may use standard input\n" if $stdin_count > 1;

    my @tables;
    my %all_key;
    for my $path (@arguments) {
        my $fh = open_text_reader($path);
        my %row_for;
        my $value_width;
        my $line_number = 0;
        while ( my $line = <$fh> ) {
            $line_number++;
            $line =~ s/\r?\n\z//;
            my @fields = split /\t/, $line, -1;
            die "Table $path line $line_number must contain a key and at least one value\n"
              unless @fields >= 2;
            my $key = shift @fields;
            die "Empty key in $path at line $line_number\n" unless length $key;
            $value_width = scalar @fields unless defined $value_width;
            die "Inconsistent column count in $path at line $line_number\n"
              unless @fields == $value_width;
            die "Duplicate key '$key' in $path at line $line_number\n"
              if exists $row_for{$key};
            $row_for{$key} = \@fields;
            $all_key{$key} = 1;
        }
        close $fh unless $path eq '-';
        die "Input table is empty: $path\n" unless defined $value_width;
        push @tables, { rows => \%row_for, width => $value_width };
    }

    for my $key ( sort keys %all_key ) {
        my @output = ($key);
        for my $table (@tables) {
            if ( exists $table->{rows}{$key} ) {
                push @output, @{ $table->{rows}{$key} };
            }
            else {
                push @output, ($missing) x $table->{width};
            }
        }
        print join( "\t", @output ), "\n";
    }
    return 0;
}

1;
