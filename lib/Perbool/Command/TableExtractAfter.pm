package Perbool::Command::TableExtractAfter;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::IO qw(open_text_reader);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool table extract-after --column N --prefix TEXT [--in TABLE.tsv.gz]
       format_column_name.pl COLUMN PREFIX < TABLE.tsv

Replace the selected 1-based tab-delimited column with the contiguous word
characters immediately following the first literal PREFIX. Input defaults to
standard input. Missing columns, prefixes, or suffixes are errors.
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $column, $prefix, $input_path );

    if ( @arguments == 2 && $arguments[0] !~ /^-/ ) {
        ( $column, $prefix ) = @arguments;
        @arguments = ();
        $input_path = '-';
    }
    else {
        my $options_ok = GetOptionsFromArray(
            \@arguments,
            'help|h'     => \$help,
            'column|c=i' => \$column,
            'prefix|p=s' => \$prefix,
            'in|i=s'     => \$input_path,
        );
        die usage_text() unless $options_ok;
        if ($help) {
            print usage_text();
            return 0;
        }
        die "Unexpected arguments: @arguments\n" if @arguments;
        $input_path = '-' unless defined $input_path;
    }

    die "--column must be a positive integer\n"
      unless defined $column && $column > 0;
    die "--prefix must not be empty\n" unless defined $prefix && length $prefix;

    my $fh = open_text_reader($input_path);
    my $line_number = 0;
    while ( my $line = <$fh> ) {
        $line_number++;
        $line =~ s/\r?\n\z//;
        my @fields = split /\t/, $line, -1;
        die "Missing column $column at input line $line_number\n"
          if $column > @fields;
        my $value = $fields[ $column - 1 ];
        my $prefix_offset = index( $value, $prefix );
        die "Prefix '$prefix' not found in column $column at input line $line_number\n"
          if $prefix_offset < 0;
        my $suffix = substr( $value, $prefix_offset + length $prefix );
        $suffix =~ /\A(\w+)/
          or die "No word suffix after prefix '$prefix' at input line $line_number\n";
        $fields[ $column - 1 ] = $1;
        print join( "\t", @fields ), "\n";
    }
    close $fh unless $input_path eq '-';
    return 0;
}

1;
