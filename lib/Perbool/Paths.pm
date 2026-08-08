package Perbool::Paths;

use strict;
use warnings;

use Cwd qw(abs_path);
use Exporter qw(import);
use File::Spec;

our @EXPORT_OK = qw(assert_distinct_paths);

sub assert_distinct_paths {
    my ( $input_path, $output_path ) = @_;
    return if $input_path eq '-' || $output_path eq '-';

    if ( -e $input_path && -e $output_path ) {
        my @input_stat = stat $input_path;
        my @output_stat = stat $output_path;
        die "Input and output must refer to different files\n"
          if @input_stat
          && @output_stat
          && $input_stat[0] == $output_stat[0]
          && $input_stat[1] == $output_stat[1];
    }

    my $resolved_input = abs_path($input_path);
    my $resolved_output =
      -e $output_path
      ? abs_path($output_path)
      : File::Spec->canonpath( File::Spec->rel2abs($output_path) );

    die "Input and output must refer to different files\n"
      if defined $resolved_input
      && defined $resolved_output
      && $resolved_input eq $resolved_output;
}

1;
