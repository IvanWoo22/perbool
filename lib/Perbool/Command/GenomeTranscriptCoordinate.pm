package Perbool::Command::GenomeTranscriptCoordinate;

use strict;
use warnings;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::IO qw(open_text_reader);
use Perbool::IntervalSet;

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool genome transcript-coordinate --transcript ID --position N
       [--in RANGES.tsv[.gz]]
       coordinate_position.pl ID N < RANGES.tsv

Map a 1-based transcript position to a genomic coordinate. Input rows contain
REFERENCE, START, END, STRAND, and GFF attributes as tab-delimited fields;
START and END are 1-based inclusive. Parent=transcript:ID values select the
transcript, and comma-separated parents are supported. Standard input is the
default; gzip input is supported.
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $input_path, $transcript, $position );
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'       => \$help,
        'in|i=s'       => \$input_path,
        'transcript|t=s' => \$transcript,
        'position|p=s' => \$position,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    if (@arguments) {
        die "Positional transcript and position cannot be combined with options\n"
          if defined $transcript || defined $position;
        die usage_text() unless @arguments == 2;
        ( $transcript, $position ) = @arguments;
    }
    die "--transcript and --position are required\n"
      unless defined $transcript && defined $position;
    die "Transcript ID must not be empty\n" unless length $transcript;
    die "Transcript position must be a positive integer\n"
      unless $position =~ /\A\d+\z/ && $position > 0;
    $input_path = '-' unless defined $input_path;

    my ( %range_for, %reference_for, %strand_for );
    my $fh = open_text_reader($input_path);
    my $line_number = 0;
    while ( my $line = <$fh> ) {
        $line_number++;
        $line =~ s/\r?\n\z//;
        next if $line =~ /\A\s*(?:#|\z)/;
        my @fields = split /\t/, $line, -1;
        die "Range input $input_path line $line_number must contain 5 tab-delimited fields\n"
          unless @fields == 5;
        my ( $reference, $start, $end, $strand, $attributes ) = @fields;
        die "Empty reference name in $input_path at line $line_number\n"
          unless length $reference;
        die "Invalid strand '$strand' in $input_path at line $line_number\n"
          unless $strand eq '+' || $strand eq '-';
        die "Start and end must be positive integers in $input_path at line $line_number\n"
          unless $start =~ /\A\d+\z/ && $start > 0
          && $end =~ /\A\d+\z/ && $end > 0;
        die "Start must not exceed end in $input_path at line $line_number\n"
          if $start > $end;

        my @parents = _transcript_parents($attributes);
        die "Missing Parent transcript in $input_path at line $line_number\n"
          unless @parents;
        for my $parent (@parents) {
            if ( exists $reference_for{$parent} ) {
                die "Transcript '$parent' occurs on multiple references\n"
                  if $reference_for{$parent} ne $reference;
                die "Transcript '$parent' occurs on multiple strands\n"
                  if $strand_for{$parent} ne $strand;
            }
            else {
                $reference_for{$parent} = $reference;
                $strand_for{$parent} = $strand;
                $range_for{$parent} = Perbool::IntervalSet->new;
            }
            $range_for{$parent}->add_range( $start, $end );
        }
    }
    close $fh unless $input_path eq '-';

    die "Transcript '$transcript' was not found in $input_path\n"
      unless exists $range_for{$transcript};
    my $ordinal = $strand_for{$transcript} eq '+' ? $position : -$position;
    my $coordinate = $range_for{$transcript}->at($ordinal);
    die "Transcript position $position exceeds the length of '$transcript' ("
      . $range_for{$transcript}->cardinality . ")\n"
      unless defined $coordinate;
    print "$reference_for{$transcript}\t$coordinate\n";
    return 0;
}

sub _transcript_parents {
    my $attributes = shift;
    my ($parent_value) = $attributes =~ /(?:\A|;)\s*Parent=([^;]+)/;
    return unless defined $parent_value;
    my @parents;
    for my $parent ( split /,/, $parent_value ) {
        $parent =~ s/^\s+|\s+$//g;
        next unless $parent =~ s/\Atranscript://;
        die "Empty transcript ID in Parent attribute\n" unless length $parent;
        push @parents, $parent;
    }
    return @parents;
}

1;
