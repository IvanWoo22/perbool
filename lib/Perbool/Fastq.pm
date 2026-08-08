package Perbool::Fastq;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use IO::Zlib;
use Perbool::Paths qw(assert_distinct_paths);

our @EXPORT_OK = qw(
  assert_distinct_paths
  fastq_id
  open_fastq_reader
  open_fastq_writer
  paired_fastq_id
  quality_text
  read_fastq_record
  sequence_text
  write_fastq_record
);

sub open_fastq_reader {
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

sub open_fastq_writer {
    my $path = shift;
    return *STDOUT{IO} if $path eq '-';

    if ( $path =~ /[.]gz\z/i ) {
        my $fh = IO::Zlib->new( $path, 'wb9' )
          or die "Cannot open $path: $!\n";
        return $fh;
    }

    open my $fh, '>', $path;
    return $fh;
}

sub read_fastq_record {
    my ( $fh, $record_number ) = @_;
    $record_number = '?' unless defined $record_number;

    my $header = <$fh>;
    return unless defined $header;

    my $sequence  = <$fh>;
    my $separator = <$fh>;
    my $quality   = <$fh>;
    die "Truncated FASTQ record $record_number\n"
      unless defined $sequence && defined $separator && defined $quality;
    die "Invalid FASTQ header in record $record_number: $header"
      unless $header =~ /^@/;
    die "Invalid FASTQ separator in record $record_number: $separator"
      unless $separator =~ /^[+]/;

    my $sequence_value = $sequence;
    my $quality_value  = $quality;
    $sequence_value =~ s/\r?\n\z//;
    $quality_value  =~ s/\r?\n\z//;
    die "Sequence and quality lengths differ in FASTQ record $record_number\n"
      unless length($sequence_value) == length($quality_value);

    return {
        header    => $header,
        sequence  => $sequence,
        separator => $separator,
        quality   => $quality,
    };
}

sub fastq_id {
    my $record = shift;
    $record->{header} =~ /^@(\S+)/
      or die "Invalid FASTQ header: $record->{header}";
    return $1;
}

sub paired_fastq_id {
    my $record = shift;
    my $id = fastq_id($record);
    $id =~ s{/([12])\z}{};
    return $id;
}

sub sequence_text {
    my $record = shift;
    my $sequence = $record->{sequence};
    $sequence =~ s/\r?\n\z//;
    return $sequence;
}

sub quality_text {
    my $record = shift;
    my $quality = $record->{quality};
    $quality =~ s/\r?\n\z//;
    return $quality;
}

sub write_fastq_record {
    my ( $fh, $record ) = @_;
    print {$fh} @{$record}{qw(header sequence separator quality)};
}

1;
