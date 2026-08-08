use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use IO::Zlib;
use IPC::Open3;
use Symbol qw(gensym);
use Test::More;

my $tempdir = tempdir( CLEANUP => 1 );

sub path_for {
    return File::Spec->catfile( $tempdir, shift );
}

sub write_text {
    my ( $path, $content ) = @_;
    open my $fh, '>', $path or die "Cannot write $path: $!";
    print {$fh} $content;
    close $fh;
}

sub write_gzip {
    my ( $path, $content ) = @_;
    my $fh = IO::Zlib->new( $path, 'wb9' )
      or die "Cannot write $path: $!";
    print {$fh} $content;
    close $fh;
}

sub read_text {
    my $path = shift;
    open my $fh, '<', $path or die "Cannot read $path: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    return $content;
}

sub run_command {
    my ( $input, @command ) = @_;
    my $stderr = gensym;
    my $pid = open3( my $child_in, my $child_out, $stderr, @command );
    print {$child_in} $input if defined $input;
    close $child_in;
    my $stdout_text = do { local $/; <$child_out> };
    my $stderr_text = do { local $/; <$stderr> };
    waitpid $pid, 0;
    return ( $?, $stdout_text, $stderr_text );
}

my $sample1_content =
    "\@one\nAAA\n+\nIII\n"
  . "\@two\nCG\n+\nJJ\n";
my $sample2_content = "\@three\nTTN\n+\nKKK\n";
my $sample1_path = path_for('sample1.fq');
my $sample2_path = path_for('sample2.fq.gz');
my $prefix = path_for('summary');
write_text( $sample1_path, $sample1_content );
write_gzip( $sample2_path, $sample2_content );

is(
    system(
        $^X, 'qc/se_fqc.pl', '--no-plot',
        $sample1_path, $sample2_path, $prefix,
    ),
    0,
    'single-end QC summary exits successfully without plotting',
);
ok( !-e $prefix . '.pdf', '--no-plot does not create a PDF' );

my $header = "$sample1_path\t$sample2_path\n";
is(
    read_text( $prefix . '_body.tsv' ),
    $header . "3\t0\n1\t0\n1\t0\n0\t2\n5\t2\n",
    'body table reports weighted A/G/C/T and canonical-base totals',
);
is(
    read_text( $prefix . '_head.tsv' ),
    $header . "1\t0\n0\t0\n1\t0\n0\t1\n2\t1\n",
    'head table reports first-base counts and read totals',
);
is(
    read_text( $prefix . '_tail.tsv' ),
    $header . "1\t0\n1\t0\n0\t0\n0\t0\n2\t1\n",
    'tail table keeps ambiguous tail reads in the total only',
);
is(
    read_text( $prefix . '_summary.tsv' ),
    $header . "2\t1\n2 - 3\t3 - 3\n",
    'summary table reports read counts and observed length ranges',
);
is(
    read_text( $prefix . '_length.tsv' ),
    "$sample1_path\t2\t1\n"
      . "$sample1_path\t3\t1\n"
      . "$sample2_path\t3\t1\n",
    'length distribution is ordered by sample and numeric length',
);

my $normalized_prefix = path_for('normalized-summary');
my ( $normalized_status, $normalized_output, $normalized_error ) = run_command(
    undef, 'bin/perbool', 'qc', 'summary', '--no-plot',
    '--out-prefix', $normalized_prefix, $sample1_path, $sample2_path,
);
is( $normalized_status, 0, 'normalized QC summary exits successfully' );
is( $normalized_output, '', 'normalized QC summary emits no standard output' );
is( $normalized_error, '', 'normalized QC summary emits no errors' );
is(
    read_text( $normalized_prefix . '_summary.tsv' ),
    read_text( $prefix . '_summary.tsv' ),
    'normalized and legacy QC summaries agree',
);

my $fake_plot_script = path_for('fake_plot.pl');
write_text(
    $fake_plot_script,
    <<'FAKE_PLOT',
use strict;
use warnings;
die "expected six plot paths\n" unless @ARGV == 6;
for my $input ( @ARGV[ 0 .. 4 ] ) {
    die "missing staged input $input\n" unless -s $input;
}
open my $pdf, '>', $ARGV[5] or die "Cannot write $ARGV[5]: $!";
print {$pdf} "%PDF-1.4 fake\n";
close $pdf;
FAKE_PLOT
);
my $plotted_prefix = path_for('plotted-summary');
my ( $plot_status, $plot_output, $plot_error ) = run_command(
    undef, 'bin/perbool', 'qc', 'summary',
    '--out-prefix', $plotted_prefix, '--rscript', $^X,
    '--plot-script', $fake_plot_script, $sample1_path,
);
is( $plot_status, 0, 'QC summary can invoke a configured plot backend' );
is( $plot_output, '', 'plotted QC summary emits no standard output' );
is( $plot_error, '', 'configured plot backend emits no errors' );
is( read_text( $plotted_prefix . '.pdf' ), "%PDF-1.4 fake\n", 'staged PDF is committed' );
ok( -s $plotted_prefix . '_body.tsv', 'staged TSVs are committed with the PDF' );

my $failing_plot_script = path_for('failing_plot.pl');
write_text( $failing_plot_script, "exit 17;\n" );
my $failed_plot_prefix = path_for('failed-plot');
write_text( $failed_plot_prefix . '_summary.tsv', "preserved summary\n" );
my ( $failed_plot_status, $failed_plot_output, $failed_plot_error ) = run_command(
    undef, 'bin/perbool', 'qc', 'summary',
    '--out-prefix', $failed_plot_prefix, '--rscript', $^X,
    '--plot-script', $failing_plot_script, $sample1_path,
);
isnt( $failed_plot_status, 0, 'failed plot backend is reported' );
is( $failed_plot_output, '', 'failed plot backend produces no output' );
like( $failed_plot_error, qr/exit code 17/, 'plot failure includes its exit code' );
is(
    read_text( $failed_plot_prefix . '_summary.tsv' ),
    "preserved summary\n",
    'plot failure preserves an existing summary',
);
ok( !-e $failed_plot_prefix . '_body.tsv', 'plot failure commits no staged TSVs' );
ok( !-e $failed_plot_prefix . '.pdf', 'plot failure commits no PDF' );

my $broken_path = path_for('broken.fq');
my $broken_prefix = path_for('broken-summary');
write_text( $broken_path, "\@bad\nAAAA\n+\nIII\n" );
isnt(
    system(
        $^X, 'qc/se_fqc.pl', '--no-plot', $broken_path, $broken_prefix,
    ),
    0,
    'single-end QC rejects malformed FASTQ before writing summaries',
);
ok(
    !-e $broken_prefix . '_summary.tsv',
    'failed validation does not leave a partial summary table',
);

my $collision_prefix = path_for('collision');
my $collision_input = $collision_prefix . '_summary.tsv';
write_text( $collision_input, $sample1_content );
my ( $collision_status, $collision_output, $collision_error ) = run_command(
    undef, 'bin/perbool', 'qc', 'summary', '--no-plot',
    '--out-prefix', $collision_prefix, $collision_input,
);
isnt( $collision_status, 0, 'QC input/output path collision is rejected' );
is( $collision_output, '', 'QC path collision produces no output' );
like( $collision_error, qr/different files/, 'QC path collision error is clear' );
is( read_text($collision_input), $sample1_content, 'path collision preserves FASTQ input' );

done_testing();
