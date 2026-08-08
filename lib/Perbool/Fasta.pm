package Perbool::Fasta;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use Perbool::IO qw(open_text_reader open_text_writer);
use Perbool::Paths qw(assert_distinct_paths);

our @EXPORT_OK = qw(
  assert_distinct_paths
  extract_interval
  fasta_id
  fasta_iterator
  load_fasta_sequences
  open_fasta_reader
  open_fasta_writer
  reverse_complement
  rna_to_dna
  sequence_text
  write_fasta_record
);

sub open_fasta_reader {
    return open_text_reader(@_);
}

sub open_fasta_writer {
    return open_text_writer(@_);
}

sub fasta_iterator {
    my $fh = shift;
    my $pending_header;
    my $line_number = 0;
    my $record_number = 0;
    my $finished = 0;

    return sub {
        return if $finished;

        my $header;
        if ( defined $pending_header ) {
            $header = $pending_header;
            undef $pending_header;
        }
        else {
            while ( my $line = <$fh> ) {
                $line_number++;
                next if $line =~ /^\s*\z/;
                die "FASTA sequence found before the first header at line $line_number\n"
                  unless $line =~ /^>/;
                $header = $line;
                last;
            }
        }

        if ( !defined $header ) {
            $finished = 1;
            return;
        }

        $record_number++;
        $header =~ s/\r?\n\z//;
        $header =~ /^>(\S+)/
          or die "Invalid FASTA header in record $record_number: $header\n";
        my $id = $1;
        my $sequence = '';

        while ( my $line = <$fh> ) {
            $line_number++;
            if ( $line =~ /^>/ ) {
                $pending_header = $line;
                last;
            }
            $line =~ s/\r?\n\z//;
            next unless length $line;
            $sequence .= $line;
        }

        $finished = 1 unless defined $pending_header;
        die "Empty FASTA sequence in record $record_number ($id)\n"
          unless length $sequence;

        return {
            header   => $header,
            id       => $id,
            sequence => $sequence,
        };
    };
}

sub fasta_id {
    my $record = shift;
    return $record->{id} if defined $record->{id};
    $record->{header} =~ /^>(\S+)/
      or die "Invalid FASTA header: $record->{header}\n";
    return $1;
}

sub load_fasta_sequences {
    my $path = shift;
    my $fh = open_fasta_reader($path);
    my $next_record = fasta_iterator($fh);
    my %sequences;
    my @ids;

    while ( my $record = $next_record->() ) {
        my $id = fasta_id($record);
        die "Duplicate FASTA ID: $id\n" if exists $sequences{$id};
        $sequences{$id} = sequence_text($record);
        push @ids, $id;
    }
    close $fh unless $path eq '-';

    return ( \%sequences, \@ids );
}

sub rna_to_dna {
    my $sequence = shift;
    $sequence =~ tr/Uu/Tt/;
    return $sequence;
}

sub reverse_complement {
    my $sequence = reverse shift;
    $sequence =~ tr/ACGTRYMKSWBDHVNUXacgtrymkswbdhvnux/TGCAYRKMSWVHDBNAXtgcayrkmswvhdbnax/;
    return $sequence;
}

sub extract_interval {
    my ( $sequence, $start, $end, $label ) = @_;
    $label = 'sequence' unless defined $label && length $label;

    die "Interval start must be a positive integer for $label\n"
      unless defined $start && $start =~ /\A[1-9]\d*\z/;
    die "Interval end must be a positive integer for $label\n"
      unless defined $end && $end =~ /\A[1-9]\d*\z/;

    my ( $left, $right ) = $start <= $end ? ( $start, $end ) : ( $end, $start );
    my $sequence_length = length $sequence;
    die "Interval $start-$end exceeds sequence length for $label ($sequence_length)\n"
      if $right > $sequence_length;

    return substr( $sequence, $left - 1, $right - $left + 1 );
}

sub sequence_text {
    my $record = shift;
    return $record->{sequence};
}

sub write_fasta_record {
    my ( $fh, $record ) = @_;
    my $header = $record->{header};
    $header = ">$header" unless $header =~ /^>/;
    $header =~ s/\r?\n\z//;
    my $sequence = sequence_text($record);
    $sequence =~ s/\r?\n\z//;
    print {$fh} "$header\n$sequence\n";
}

1;
