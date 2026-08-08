package Perbool::Command::LiteraturePubmedSearch;

use strict;
use warnings;

use Cwd qw(abs_path);
use Exporter qw(import);
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempdir tempfile);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::IO qw(open_text_reader open_text_writer);
use Perbool::Paths qw(assert_distinct_paths);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool literature pubmed-search --queries QUERIES.txt[.gz]
       [--out RESULTS.txt[.gz]] [--min-year YEAR] [--max-year YEAR]
       [--retmax N] [--work-dir DIR] [--rscript PROGRAM]
       extract_pubmed_info.pl QUERIES.txt WORK_DIR RESULTS.txt

Run the bundled RISmed query backend once for each nonblank query. Results use
the historical framing: query line, CSV result block, and a blank separator.
Output defaults to standard output and is only opened after every query has
succeeded. The default year range is 2010 through the current year.
USAGE
}

sub run {
    my @arguments = @_;
    my $current_year = ( localtime )[5] + 1900;
    my ( $help, $queries_path, $output_path, $work_dir, $r_script );
    my $rscript = 'Rscript';
    my $min_year = 2010;
    my $max_year = $current_year;
    my $retmax = 100;
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'       => \$help,
        'queries|q=s'  => \$queries_path,
        'out|o=s'      => \$output_path,
        'work-dir|w=s' => \$work_dir,
        'rscript=s'    => \$rscript,
        'r-script=s'   => \$r_script,
        'min-year=i'   => \$min_year,
        'max-year=i'   => \$max_year,
        'retmax=i'     => \$retmax,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    if (@arguments) {
        die "Positional inputs cannot be combined with command options\n"
          if defined $queries_path || defined $output_path || defined $work_dir;
        die usage_text() unless @arguments == 3;
        ( $queries_path, $work_dir, $output_path ) = @arguments;
    }
    die "--queries is required\n" unless defined $queries_path;
    $output_path = '-' unless defined $output_path;
    die "--min-year and --max-year must be four-digit years\n"
      unless $min_year >= 1000 && $min_year <= 9999
      && $max_year >= 1000 && $max_year <= 9999;
    die "--min-year must not exceed --max-year\n" if $min_year > $max_year;
    die "--retmax must be a positive integer\n" unless $retmax > 0;
    die "--work-dir is not a directory: $work_dir\n"
      if defined $work_dir && !-d $work_dir;
    assert_distinct_paths( $queries_path, $output_path );

    $r_script = _default_r_script() unless defined $r_script;
    die "R query script does not exist: $r_script\n" unless -f $r_script;
    my $queries = _load_queries($queries_path);

    my @temp_arguments = ( 'perbool-pubmed-XXXXXX', CLEANUP => 1 );
    push @temp_arguments, ( DIR => $work_dir ) if defined $work_dir;
    my $temporary_directory = tempdir(@temp_arguments);
    my ( $aggregate_fh, $aggregate_path ) = tempfile(
        'aggregate-XXXXXX',
        DIR    => $temporary_directory,
        UNLINK => 0,
    );

    for my $index ( 0 .. $#{$queries} ) {
        my ( $result_fh, $result_path ) = tempfile(
            sprintf( 'result-%06d-XXXXXX', $index + 1 ),
            DIR    => $temporary_directory,
            UNLINK => 0,
        );
        close $result_fh;
        _run_r_query(
            $rscript, $r_script, $queries->[$index], $result_path,
            $min_year, $max_year, $retmax,
        );
        die "R query produced an empty result for '$queries->[$index]'\n"
          unless -s $result_path;

        print {$aggregate_fh} "$queries->[$index]\n";
        open my $result_reader, '<', $result_path;
        my $last_character = '';
        while ( read $result_reader, my $buffer, 64 * 1024 ) {
            print {$aggregate_fh} $buffer;
            $last_character = substr( $buffer, -1 );
        }
        close $result_reader;
        print {$aggregate_fh} "\n" unless $last_character eq "\n";
        print {$aggregate_fh} "\n";
    }
    close $aggregate_fh;

    my $output_fh = open_text_writer($output_path);
    open my $aggregate_reader, '<', $aggregate_path;
    while ( read $aggregate_reader, my $buffer, 64 * 1024 ) {
        print {$output_fh} $buffer;
    }
    close $aggregate_reader;
    close $output_fh unless $output_path eq '-';
    return 0;
}

sub _default_r_script {
    my $path = File::Spec->catfile(
        dirname(__FILE__), qw(.. .. .. extract_pubmed_info pubmed_data.R),
    );
    return abs_path($path) || $path;
}

sub _load_queries {
    my $path = shift;
    my $fh = open_text_reader($path);
    my @queries;
    my $line_number = 0;
    while ( my $line = <$fh> ) {
        $line_number++;
        $line =~ s/\r?\n\z//;
        next if $line =~ /\A\s*\z/;
        die "Control character in query input $path at line $line_number\n"
          if $line =~ /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/;
        push @queries, $line;
    }
    close $fh unless $path eq '-';
    die "Query input contains no nonblank queries: $path\n" unless @queries;
    return \@queries;
}

sub _run_r_query {
    my ( $rscript, $r_script, $query, $result_path, $min_year, $max_year,
        $retmax ) = @_;
    my $status = system {
        $rscript
    } $rscript, $r_script, $query, $result_path, $min_year, $max_year, $retmax;
    die "Cannot execute $rscript: $!\n" if $status == -1;
    die "$rscript was terminated by signal " . ( $status & 127 ) . "\n"
      if $status & 127;
    my $exit_code = $status >> 8;
    die "$rscript failed for query '$query' with exit code $exit_code\n"
      if $exit_code != 0;
}

1;
