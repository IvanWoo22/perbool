package Perbool::Command::TableIntersect;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::IO qw(open_text_reader);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool table intersect-lines --left FILE1 --right FILE2 [--unique]
       compare_file.pl FILE1 FILE2

Print exact lines from FILE2 that also occur in FILE1, preserving FILE2 order.
Repeated matching lines are retained unless --unique is supplied. Gzip input
is detected by the .gz suffix; at most one input may be standard input (-).
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $left_path, $right_path, $unique );

    if ( @arguments == 2 && $arguments[0] !~ /^--/ ) {
        ( $left_path, $right_path ) = @arguments;
        @arguments = ();
    }
    else {
        my $options_ok = GetOptionsFromArray(
            \@arguments,
            'help|h'    => \$help,
            'left|l=s'  => \$left_path,
            'right|r=s' => \$right_path,
            'unique|u'  => \$unique,
        );
        die usage_text() unless $options_ok;
        if ($help) {
            print usage_text();
            return 0;
        }
        die "Unexpected arguments: @arguments\n" if @arguments;
    }

    die "--left and --right are required\n"
      unless defined $left_path && defined $right_path;
    die "Only one input may use standard input\n"
      if $left_path eq '-' && $right_path eq '-';

    my %left_line;
    my $left_fh = open_text_reader($left_path);
    while ( my $line = <$left_fh> ) {
        $line =~ s/\r?\n\z//;
        $left_line{$line} = 1;
    }
    close $left_fh unless $left_path eq '-';

    my %emitted;
    my $right_fh = open_text_reader($right_path);
    while ( my $line = <$right_fh> ) {
        $line =~ s/\r?\n\z//;
        next unless exists $left_line{$line};
        next if $unique && $emitted{$line}++;
        print "$line\n";
    }
    close $right_fh unless $right_path eq '-';
    return 0;
}

1;
