package Perbool::Command::ReverseComplement;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use Perbool::Fasta qw(reverse_complement);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool sequence reverse-complement SEQUENCE
       perbool sequence reverse-complement - < sequence.txt

Reverse-complement a DNA/RNA sequence using standard IUPAC ambiguity symbols
plus X. Whitespace is removed only when reading from standard input.
USAGE
}

sub run {
    my @arguments = @_;
    if ( @arguments == 1 && ( $arguments[0] eq '--help' || $arguments[0] eq '-h' ) ) {
        print usage_text();
        return 0;
    }
    die usage_text() unless @arguments == 1;

    my $sequence = $arguments[0];
    if ( $sequence eq '-' ) {
        $sequence = do { local $/; <STDIN> };
        $sequence = '' unless defined $sequence;
        $sequence =~ s/\s+//g;
    }
    die "Sequence must not be empty\n" unless length $sequence;
    die "Sequence contains non-IUPAC characters\n"
      if $sequence =~ /[^ACGTRYMKSWBDHVNUXacgtrymkswbdhvnux]/;

    print reverse_complement($sequence), "\n";
    return 0;
}

1;
