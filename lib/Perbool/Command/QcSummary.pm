package Perbool::Command::QcSummary;

use strict;
use warnings;
use autodie;

use Cwd qw(abs_path);
use Exporter qw(import);
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempdir);
use Getopt::Long qw(GetOptionsFromArray);
use Perbool::Paths qw(assert_distinct_paths);
use Perbool::QC qw(summarize_fastq);

our @EXPORT_OK = qw(run usage_text);

sub usage_text {
    return <<'USAGE';
Usage: perbool qc summary [--no-plot] --out-prefix PREFIX INPUT.fq[.gz] ...
       qc/se_fqc.pl [--no-plot] INPUT.fq[.gz] ... PREFIX

Write base-composition, terminal-base, length-distribution, and summary TSVs.
Unless --no-plot is used, also render PREFIX.pdf with the bundled R script.
All FASTQ inputs validate and all staged outputs complete before final files are
replaced. At most one input may use standard input.
USAGE
}

sub run {
    my @arguments = @_;
    my ( $help, $no_plot, $output_prefix, $plot_script );
    my $rscript = 'Rscript';
    my $options_ok = GetOptionsFromArray(
        \@arguments,
        'help|h'       => \$help,
        'no-plot'      => \$no_plot,
        'out-prefix=s' => \$output_prefix,
        'rscript=s'    => \$rscript,
        'plot-script=s' => \$plot_script,
    );
    die usage_text() unless $options_ok;
    if ($help) {
        print usage_text();
        return 0;
    }
    if ( !defined $output_prefix ) {
        die "At least one FASTQ input and an output prefix are required\n"
          unless @arguments >= 2;
        $output_prefix = pop @arguments;
    }
    die "At least one FASTQ input is required\n" unless @arguments;
    die "Output prefix must not be empty\n" unless length $output_prefix;
    my @input_paths = @arguments;
    my $stdin_count = grep { $_ eq '-' } @input_paths;
    die "Only one FASTQ input may use standard input\n" if $stdin_count > 1;

    my %output_path = (
        body    => $output_prefix . '_body.tsv',
        head    => $output_prefix . '_head.tsv',
        tail    => $output_prefix . '_tail.tsv',
        summary => $output_prefix . '_summary.tsv',
        length  => $output_prefix . '_length.tsv',
        pdf     => $output_prefix . '.pdf',
    );
    my $output_directory = dirname($output_prefix);
    die "Output directory does not exist: $output_directory\n"
      unless -d $output_directory;
    for my $path ( values %output_path ) {
        die "Output path is a directory: $path\n" if -d $path;
        assert_distinct_paths( $_, $path ) for @input_paths;
    }

    my @stats = map { summarize_fastq($_) } @input_paths;
    my $staging_directory = tempdir(
        '.perbool-qc-XXXXXX',
        DIR     => $output_directory,
        CLEANUP => 1,
    );
    my %staged = map {
        $_ => File::Spec->catfile(
            $staging_directory, $_ eq 'pdf' ? 'summary.pdf' : "$_.tsv",
        )
    } keys %output_path;

    _write_base_table( $staged{body}, 'body', \@input_paths, \@stats );
    _write_base_table( $staged{head}, 'head', \@input_paths, \@stats );
    _write_base_table( $staged{tail}, 'tail', \@input_paths, \@stats );
    _write_summary_table( $staged{summary}, \@input_paths, \@stats );
    _write_length_table( $staged{length}, \@input_paths, \@stats );

    unless ($no_plot) {
        $plot_script = _default_plot_script() unless defined $plot_script;
        die "QC plot script does not exist: $plot_script\n" unless -f $plot_script;
        _run_plot(
            $rscript, $plot_script, $staged{body}, $staged{head},
            $staged{tail}, $staged{length}, $staged{summary}, $staged{pdf},
        );
        die "QC plot did not create a nonempty PDF\n" unless -s $staged{pdf};
    }

    for my $section (qw(body head tail summary length)) {
        rename $staged{$section}, $output_path{$section};
    }
    rename $staged{pdf}, $output_path{pdf} unless $no_plot;
    return 0;
}

sub _write_base_table {
    my ( $path, $section, $input_paths, $stats ) = @_;
    open my $fh, '>', $path;
    print {$fh} join( "\t", @{$input_paths} ), "\n";
    for my $base (qw(A G C T)) {
        print {$fh} join( "\t", map { $_->{$section}{$base} } @{$stats} ), "\n";
    }
    my @totals = $section eq 'body'
      ? map {
        my $sample = $_;
        my $total = 0;
        $total += $sample->{body}{$_} for qw(A G C T);
        $total;
      } @{$stats}
      : map { $_->{reads} } @{$stats};
    print {$fh} join( "\t", @totals ), "\n";
    close $fh;
}

sub _write_summary_table {
    my ( $path, $input_paths, $stats ) = @_;
    open my $fh, '>', $path;
    print {$fh} join( "\t", @{$input_paths} ), "\n";
    print {$fh} join( "\t", map { $_->{reads} } @{$stats} ), "\n";
    print {$fh} join(
        "\t",
        map {
            defined $_->{min_length}
              ? $_->{min_length} . ' - ' . $_->{max_length}
              : 'NA'
        } @{$stats}
      ),
      "\n";
    close $fh;
}

sub _write_length_table {
    my ( $path, $input_paths, $stats ) = @_;
    open my $fh, '>', $path;
    for my $sample_index ( 0 .. $#{$input_paths} ) {
        for my $length (
            sort { $a <=> $b }
            keys %{ $stats->[$sample_index]{length_dist} }
          )
        {
            print {$fh} join(
                "\t", $input_paths->[$sample_index], $length,
                $stats->[$sample_index]{length_dist}{$length}
              ),
              "\n";
        }
    }
    close $fh;
}

sub _default_plot_script {
    my $path = File::Spec->catfile(
        dirname(__FILE__), qw(.. .. .. qc draw_picture.R),
    );
    return abs_path($path) || $path;
}

sub _run_plot {
    my ( $rscript, @arguments ) = @_;
    my $status = system {$rscript} $rscript, @arguments;
    die "Cannot execute $rscript: $!\n" if $status == -1;
    die "$rscript was terminated by signal " . ( $status & 127 ) . "\n"
      if $status & 127;
    my $exit_code = $status >> 8;
    die "$rscript failed while rendering QC output with exit code $exit_code\n"
      if $exit_code != 0;
}

1;
