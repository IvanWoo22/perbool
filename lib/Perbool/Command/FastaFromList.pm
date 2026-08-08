package Perbool::Command::FastaFromList;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fasta qw(rna_to_dna);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool fasta from-list --col NUMBER (--file TABLE | --stdin) [OPTIONS]

Count sequences from a delimited table column and emit deterministic FASTA.
  --sep TEXT  Literal field separator (default: tab)
  --rna2dna   Convert U/u to T/t before counting
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $separator, $column, $input_path, $stdin, $rna2dna );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'   => \$help,
        'sep|s=s'  => \$separator,
        'col|c=i'  => \$column,
        'file|f=s' => \$input_path,
        'stdin'    => \$stdin,
        'rna2dna'  => \$rna2dna,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    die "Unexpected arguments: @arguments\n" if @arguments;
    die "--col must be a positive integer\n"
      unless defined $column && $column > 0;
    die "Choose exactly one of --file and --stdin\n"
      unless ( defined($input_path) ? 1 : 0 ) + ( $stdin ? 1 : 0 ) == 1;
    $separator = "\t" unless defined $separator;
    die "--sep must not be empty\n" unless length $separator;

    my $input_fh;
    if ( defined $input_path ) {
        open $input_fh, '<', $input_path;
    }
    else {
        $input_fh = *STDIN{IO};
    }

    my %count;
    my @sequence_order;
    my $line_number = 0;
    while ( my $line = <$input_fh> ) {
        $line_number++;
        $line =~ s/\r?\n\z//;
        my @fields = split /\Q$separator\E/, $line, -1;
        die "Missing column $column at input line $line_number\n"
          if $column > @fields;
        my $sequence = $fields[ $column - 1 ];
        die "Empty sequence in column $column at input line $line_number\n"
          unless length $sequence;
        die "Whitespace in sequence column at input line $line_number\n"
          if $sequence =~ /\s/;
        $sequence = rna_to_dna($sequence) if $rna2dna;

        if ( !exists $count{$sequence} ) {
            $count{$sequence} = 0;
            push @sequence_order, $sequence;
        }
        $count{$sequence}++;
    }
    close $input_fh if defined $input_path;

    my $sequence_number = 0;
    for my $sequence (@sequence_order) {
        $sequence_number++;
        my $length = length $sequence;
        print ">seq$sequence_number LENGTH=$length REPEAT=$count{$sequence}\n";
        print "$sequence\n";
    }
    return 0;
}

1;
