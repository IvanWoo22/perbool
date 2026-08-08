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

sub run_command {
    my ( $stdin_text, @command ) = @_;
    my $stderr = gensym;
    my $pid = open3( my $child_in, my $child_out, $stderr, @command );
    print {$child_in} $stdin_text if defined $stdin_text;
    close $child_in;
    my $stdout_text = do { local $/; <$child_out> };
    my $stderr_text = do { local $/; <$stderr> };
    waitpid $pid, 0;
    return ( $?, $stdout_text, $stderr_text );
}

my $qc_content =
    "\@one\nAAA\n+\nIII\n"
  . "\@two\nacgg\n+\nJJJJ\n"
  . "\@three\nTNN\n+\nKKK\n";
my $qc_path = path_for('qc.fq');
write_text( $qc_path, $qc_content );

my ( $end_status, $end_output, $end_error ) =
  run_command( undef, $^X, 'qc/end_base.pl', $qc_path );
is( $end_status, 0, 'end-base counting exits successfully' );
is( $end_error,  '', 'end-base counting emits no errors' );
is(
    $end_output,
    "A:\t1\nG:\t1\nC:\t0\nT:\t0\nTotal:\t3\n",
    'end-base counting normalizes case and retains ambiguous reads in total',
);

my $qc_gzip_path = path_for('qc.fq.gz');
write_gzip( $qc_gzip_path, $qc_content );
my ( $gzip_end_status, $gzip_end_output, $gzip_end_error ) =
  run_command( undef, $^X, 'qc/end_base.pl', $qc_gzip_path );
is( $gzip_end_status, 0, 'end-base counting accepts gzip input' );
is( $gzip_end_error,  '', 'gzip end-base counting emits no errors' );
is(
    $gzip_end_output,
    $end_output,
    'plain and gzip end-base counts are identical',
);

my ( $length_status, $length_output, $length_error ) =
  run_command( $qc_content, $^X, 'qc/length_distribution.pl' );
is( $length_status, 0, 'length distribution exits successfully' );
is( $length_error,  '', 'length distribution emits no errors' );
is(
    $length_output,
    "3\t2\n4\t1\n",
    'length distribution is numerically sorted and correctly counted',
);

my $r1_content =
    "\@pair1/1\nAAA\n+\nIII\n"
  . "\@pair2/1\nACG\n+\nJJJ\n"
  . "\@pair3/1\nTTT\n+\nKKK\n";
my $r2_content =
    "\@pair1/2\nAAA\n+\nIII\n"
  . "\@pair2/2\nCGT\n+\nJJJ\n"
  . "\@pair3/2\nCCC\n+\nKKK\n";
my $r1_path = path_for('R1.fq');
my $r2_path = path_for('R2.fq');
write_text( $r1_path, $r1_content );
write_text( $r2_path, $r2_content );

my ( $pair_status, $pair_output, $pair_error ) =
  run_command( undef, $^X, 'qc/pe_coordinate.pl', $r1_path, $r2_path );
is( $pair_status, 0, 'paired-coordinate comparison exits successfully' );
is( $pair_error,  '', 'paired-coordinate comparison emits no errors' );
is(
    $pair_output,
    "AAA\nACG\n",
    'paired-coordinate comparison finds identical and reverse-complement reads',
);

my $r1_gzip = path_for('R1.fq.gz');
my $r2_gzip = path_for('R2.fq.gz');
write_gzip( $r1_gzip, $r1_content );
write_gzip( $r2_gzip, $r2_content );
my ( $gzip_pair_status, $gzip_pair_output, $gzip_pair_error ) =
  run_command( undef, $^X, 'qc/pe_coordinate.pl', $r1_gzip, $r2_gzip );
is( $gzip_pair_status, 0, 'paired-coordinate comparison accepts gzip inputs' );
is( $gzip_pair_error,  '', 'gzip paired-coordinate comparison emits no errors' );
is(
    $gzip_pair_output,
    $pair_output,
    'plain and gzip paired-coordinate results are identical',
);

my $bad_r2_path = path_for('bad.R2.fq');
write_text( $bad_r2_path, "\@other/2\nAAA\n+\nIII\n" );
my ( $bad_pair_status, undef, $bad_pair_error ) =
  run_command( undef, $^X, 'qc/pe_coordinate.pl', $r1_path, $bad_r2_path );
isnt( $bad_pair_status, 0, 'paired-coordinate comparison rejects ID mismatch' );
like(
    $bad_pair_error,
    qr/(?:different numbers|IDs do not match)/,
    'paired-coordinate mismatch produces a clear error',
);

my $broken_content = "\@broken\nACGT\n+\nIII\n";
my ( $broken_status, undef, $broken_error ) =
  run_command( $broken_content, $^X, 'qc/length_distribution.pl' );
isnt( $broken_status, 0, 'length distribution rejects malformed FASTQ' );
like(
    $broken_error,
    qr/Sequence and quality lengths differ/,
    'malformed FASTQ reports the failing invariant',
);

done_testing();
