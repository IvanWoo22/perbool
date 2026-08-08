package Perbool::Fasta;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use IO::Zlib;

our @EXPORT_OK = qw(
  fasta_id
  fasta_iterator
  open_fasta_reader
  sequence_text
  write_fasta_record
);

sub open_fasta_reader {
    my $path = shift;
    return *STDIN{IO} if $path eq '-';

    if ( $path =~ /[.]gz\z/i ) {
        my $fh = IO::Zlib->new( $path, 'rb' )
          or die "Cannot open $path: $!\n";
        return $fh;
    }

    open my $fh, '<', $path;
    return $fh;
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
