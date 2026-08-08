package Perbool::Command::FastaSubstitute;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fasta qw(load_fasta_sequences);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool fasta substitute --fa REFERENCE.fa[.gz] (--in VARIANTS | --stdin)

Each nonblank variant line contains FASTA_ID POSITION REF ALT. POSITION is
1-based. REF and ALT contain one or more DNA/RNA IUPAC characters (X is also
accepted). Each output record represents one independent substitution against
the reference.
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $variant_path, $fasta_path, $stdin );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h' => \$help,
        'in|i=s' => \$variant_path,
        'fa|f=s' => \$fasta_path,
        'stdin'  => \$stdin,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    die "Unexpected arguments: @arguments\n" if @arguments;
    die "--fa is required\n" unless defined $fasta_path;
    die "Choose exactly one of --in and --stdin\n"
      unless ( defined($variant_path) ? 1 : 0 ) + ( $stdin ? 1 : 0 ) == 1;
    die "FASTA and variant input cannot both use standard input\n"
      if $fasta_path eq '-' && $stdin;

    my ($sequences) = load_fasta_sequences($fasta_path);
    my $variant_fh;
    if ( defined $variant_path ) {
        open $variant_fh, '<', $variant_path;
    }
    else {
        $variant_fh = *STDIN{IO};
    }

    my @output_records;
    my $line_number = 0;
    while ( my $line = <$variant_fh> ) {
        $line_number++;
        $line =~ s/\r?\n\z//;
        next if $line =~ /^\s*(?:#|\z)/;
        $line =~ s/^\s+|\s+$//g;
        my ( $id, $position, $reference, $alternate, @extra ) = split /\s+/, $line;
        die "Invalid variant at line $line_number: expected ID POSITION REF ALT\n"
          unless defined $id
          && defined $position
          && defined $reference
          && defined $alternate
          && !@extra;
        die "Variant position must be a positive integer at line $line_number\n"
          unless $position =~ /\A[1-9]\d*\z/;
        die "REF and ALT must contain only IUPAC sequence characters at line $line_number\n"
          unless $reference =~ /\A[ACGTRYMKSWBDHVNUXacgtrymkswbdhvnux]+\z/
          && $alternate =~ /\A[ACGTRYMKSWBDHVNUXacgtrymkswbdhvnux]+\z/;
        die "Unknown FASTA ID '$id' at variant line $line_number\n"
          unless exists $sequences->{$id};

        my $sequence = $sequences->{$id};
        my $right = $position + length($reference) - 1;
        die "Variant $id:$position extends beyond sequence length "
          . length($sequence) . " at line $line_number\n"
          if $right > length $sequence;
        my $observed = substr( $sequence, $position - 1, length $reference );
        die "Reference mismatch for $id:$position at line $line_number: "
          . "expected '$reference', observed '$observed'\n"
          unless uc($observed) eq uc($reference);

        substr( $sequence, $position - 1, length($reference), $alternate );
        push @output_records, [ ">$id-$position-$reference-$alternate", $sequence ];
    }
    close $variant_fh if defined $variant_path;

    for my $record (@output_records) {
        print "$record->[0]\n$record->[1]\n";
    }
    return 0;
}

1;
