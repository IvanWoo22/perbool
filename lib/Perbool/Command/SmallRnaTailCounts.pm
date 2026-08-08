package Perbool::Command::SmallRnaTailCounts;

use strict;
use warnings;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Fasta qw(fasta_iterator open_fasta_reader sequence_text);
use Perbool::IO qw(open_text_reader);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool small-rna tail-counts --counts READ_COUNTS.tsv[.gz]
       --fasta REFERENCES.fa[.gz]
       mirna_count.pl READ_COUNTS.tsv REFERENCES.fa

For each FASTA reference, print its complete header, exact read count, and the
count of longer reads with a poly(A)-like suffix. A suffix qualifies when it is
AA, AAA, or at least 4 bases long with an A fraction of 0.75 or greater.
Sequences are compared case-insensitively. Gzip input is supported; one input
may be standard input (-).
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $counts_path, $fasta_path );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'     => \$help,
        'counts|c=s' => \$counts_path,
        'fasta|f=s'  => \$fasta_path,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    if (@arguments) {
        die "Positional inputs cannot be combined with --counts or --fasta\n"
          if defined $counts_path || defined $fasta_path;
        die usage_text() unless @arguments == 2;
        ( $counts_path, $fasta_path ) = @arguments;
    }
    die "--counts and --fasta are required\n"
      unless defined $counts_path && defined $fasta_path;
    die "Only one input may use standard input\n"
      if $counts_path eq '-' && $fasta_path eq '-';

    my $read_counts = _load_read_counts($counts_path);
    my $references = _load_references($fasta_path);
    my %reference_sequence = map { ( uc sequence_text($_) ) => 1 } @{$references};
    my $tail_counts = _count_poly_a_tails( $read_counts, \%reference_sequence );
    my @output;

    for my $record ( @{$references} ) {
        my $reference = uc sequence_text($record);
        my $exact_count = $read_counts->{$reference} || 0;
        my $tail_count = $tail_counts->{$reference} || 0;
        push @output,
          join( "\t", $record->{header}, $exact_count, $tail_count );
    }

    print "$_\n" for @output;
    return 0;
}

sub _load_read_counts {
    my $path = shift;
    my $fh = open_text_reader($path);
    my %counts;
    my $line_number = 0;
    while ( my $line = <$fh> ) {
        $line_number++;
        $line =~ s/\r?\n\z//;
        next if $line =~ /\A\s*\z/;
        my @fields = split /\t/, $line, -1;
        die "Read-count input $path line $line_number must contain exactly 2 tab-delimited fields\n"
          unless @fields == 2;
        my ( $sequence, $count ) = @fields;
        die "Empty read sequence in $path at line $line_number\n"
          unless length $sequence;
        die "Read sequence contains whitespace in $path at line $line_number\n"
          if $sequence =~ /\s/;
        die "Read count must be a nonnegative integer in $path at line $line_number\n"
          unless $count =~ /\A\d+\z/;
        $counts{ uc $sequence } += $count;
    }
    close $fh unless $path eq '-';
    return \%counts;
}

sub _load_references {
    my $path = shift;
    my $fh = open_fasta_reader($path);
    my $next_record = fasta_iterator($fh);
    my @records;
    while ( my $record = $next_record->() ) {
        my $sequence = sequence_text($record);
        die "Whitespace in FASTA sequence $record->{id}\n" if $sequence =~ /\s/;
        push @records, $record;
    }
    close $fh unless $path eq '-';
    return \@records;
}

sub _count_poly_a_tails {
    my ( $read_counts, $reference_sequences ) = @_;
    my $root = { children => {} };
    for my $reference ( keys %{$reference_sequences} ) {
        my $node = $root;
        for my $base ( split //, $reference ) {
            $node->{children}{$base} ||= { children => {} };
            $node = $node->{children}{$base};
        }
        $node->{reference} = $reference;
    }

    my %tail_counts;
    for my $read ( keys %{$read_counts} ) {
        my $node = $root;
        my @bases = split //, $read;
        for my $position ( 0 .. $#bases ) {
            $node = $node->{children}{ $bases[$position] };
            last unless defined $node;
            next unless defined $node->{reference};
            my $suffix = substr( $read, $position + 1 );
            next unless length $suffix && _is_poly_a_suffix($suffix);
            $tail_counts{ $node->{reference} } += $read_counts->{$read};
        }
    }
    return \%tail_counts;
}

sub _is_poly_a_suffix {
    my $suffix = shift;
    return 1 if $suffix eq 'AA' || $suffix eq 'AAA';
    return 0 unless length($suffix) >= 4;
    my $a_count = () = $suffix =~ /A/g;
    return $a_count / length($suffix) >= 0.75 ? 1 : 0;
}

1;
