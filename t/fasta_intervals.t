use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use IO::Zlib;
use IPC::Open3;
use Symbol qw(gensym);
use Test::More;

use lib 'lib';
use Perbool::Fasta qw(
  extract_interval load_fasta_sequences reverse_complement rna_to_dna
);

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

sub read_text {
    my $path = shift;
    open my $fh, '<', $path or die "Cannot read $path: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    return $content;
}

sub write_gzip {
    my ( $path, $content ) = @_;
    my $fh = IO::Zlib->new( $path, 'wb9' )
      or die "Cannot write $path: $!";
    print {$fh} $content;
    close $fh;
}

sub read_gzip {
    my $path = shift;
    my $fh = IO::Zlib->new( $path, 'rb' )
      or die "Cannot read $path: $!";
    my $content = '';
    $content .= $_ while <$fh>;
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

is( rna_to_dna('ACGUacgu'), 'ACGTacgt', 'RNA-to-DNA conversion preserves case' );
is(
    reverse_complement('ACGTRYMKSWBDHVNU'),
    'ANBDHVWSMKRYACGT',
    'reverse complement supports RNA and all IUPAC ambiguity symbols',
);
is(
    extract_interval( 'ACGTAC', 5, 2, 'test sequence' ),
    'CGTA',
    'interval extraction normalizes reversed coordinates',
);

my $interval_error = '';
eval { extract_interval( 'ACGT', 0, 2, 'test sequence' ) };
$interval_error = $@;
like( $interval_error, qr/start must be a positive integer/, 'zero start is rejected' );
eval { extract_interval( 'ACGT', 2, 5, 'test sequence' ) };
$interval_error = $@;
like( $interval_error, qr/exceeds sequence length/, 'out-of-bounds end is rejected' );

my $search_fasta = ">chr2\nAAAA\n>chr1\nA.AA\n";
my $search_path = path_for('search.fa');
my $search_gzip_path = path_for('search.fa.gz');
write_text( $search_path, $search_fasta );
write_gzip( $search_gzip_path, $search_fasta );

my ( $loaded, $order ) = load_fasta_sequences($search_path);
is_deeply( $order, [qw(chr2 chr1)], 'FASTA loader preserves record order' );
is( $loaded->{chr1}, 'A.AA', 'FASTA loader indexes sequence by first ID' );

my $duplicate_path = path_for('duplicate.fa');
write_text( $duplicate_path, ">same\nAA\n>same duplicate\nTT\n" );
my $duplicate_error = '';
eval { load_fasta_sequences($duplicate_path) };
$duplicate_error = $@;
like( $duplicate_error, qr/Duplicate FASTA ID: same/, 'duplicate FASTA IDs are rejected' );

my ( $find_status, $find_output, $find_error ) = run_command(
    undef, $^X, 'find_seq_from_fasta.pl', '--fa', $search_path,
    '--seq', 'AA',
);
is( $find_status, 0, 'literal FASTA search exits successfully' );
is( $find_error,  '', 'literal FASTA search emits no errors' );
is(
    $find_output,
    "chr2\t2\nchr2\t3\nchr2\t4\nchr1\t4\n",
    'search is deterministic and includes overlapping matches',
);

my ( $literal_status, $literal_output, $literal_error ) = run_command(
    undef, $^X, 'find_seq_from_fasta.pl', '--fa', $search_gzip_path,
    '--seq', '.',
);
is( $literal_status, 0, 'search accepts gzip FASTA input' );
is( $literal_error,  '', 'gzip search emits no errors' );
is(
    $literal_output,
    "chr1\t2\n",
    'search metacharacters are treated literally rather than as regular expressions',
);

my $query_path = path_for('queries.txt');
write_text( $query_path, "\nAAAA\n" );
my ( $stdin_status, $stdin_output, $stdin_error ) = run_command(
    $search_fasta, $^X, 'find_seq_from_fasta.pl', '--stdin',
    '--in', $query_path,
);
is( $stdin_status, 0, 'search accepts FASTA from standard input' );
is( $stdin_error,  '', 'standard-input search emits no errors' );
is( $stdin_output, "chr2\t4\n", 'blank query-list lines are ignored' );

my $gzip_query_path = path_for('queries.txt.gz');
my $find_output_path = path_for('matches.tsv.gz');
write_gzip( $gzip_query_path, "AA\n" );
is(
    system(
        'bin/perbool', 'fasta', 'find', '--fa', $search_gzip_path,
        '--in', $gzip_query_path, '--out', $find_output_path,
    ),
    0,
    'normalized FASTA search supports gzip query and result files',
);
is(
    read_gzip($find_output_path),
    $find_output,
    'normalized FASTA search agrees with the legacy interface',
);
my ( $find_stdin_conflict_status, $find_stdin_conflict_output,
    $find_stdin_conflict_error ) = run_command(
    $search_fasta, 'bin/perbool', 'fasta', 'find', '--stdin', '--in', '-',
);
isnt( $find_stdin_conflict_status, 0, 'search rejects two standard-input sources' );
is( $find_stdin_conflict_output, '', 'search input conflict produces no output' );
like(
    $find_stdin_conflict_error,
    qr/cannot both use standard input/,
    'search input conflict is clear',
);

my $interval_fasta = ">chr1 description\nACGURYMK\n>NC_000001.11\n" . ( 'A' x 75 ) . "\n";
my $interval_path = path_for('interval.fa');
my $interval_gzip_path = path_for('interval.fa.gz');
write_text( $interval_path, $interval_fasta );
write_gzip( $interval_gzip_path, $interval_fasta );

my $pick_path = path_for('intervals.txt');
write_text(
    $pick_path,
    "# comment\n  chr1 2 5 + plus  \n\nchr1 5 2 - minus\n",
);
my $expected_pick =
  ">chr1:2-5(+)plus\nCGTR\n>chr1:5-2(-)minus\nYACG\n";
my ( $pick_status, $pick_output, $pick_error ) = run_command(
    undef, $^X, 'pick_seq_from_fasta_neo.pl', '--fa', $interval_gzip_path,
    '--in', $pick_path,
);
is( $pick_status, 0, 'interval extraction accepts gzip FASTA input' );
is( $pick_error,  '', 'interval extraction emits no errors' );
is(
    $pick_output,
    $expected_pick,
    'interval extraction handles RNA conversion, reverse coordinates, and strand',
);

my $gzip_pick_path = path_for('intervals.txt.gz');
my $normalized_pick_path = path_for('interval-output.fa.gz');
write_gzip( $gzip_pick_path, read_text($pick_path) );
is(
    system(
        'bin/perbool', 'fasta', 'extract-intervals', '--fa', $interval_gzip_path,
        '--intervals', $gzip_pick_path, '--out', $normalized_pick_path,
    ),
    0,
    'normalized interval extraction supports gzip list and output files',
);
is(
    read_gzip($normalized_pick_path),
    $expected_pick,
    'normalized and legacy interval extraction agree',
);

my ( $legacy_status, $legacy_output, $legacy_error ) =
  run_command( undef, $^X, 'pick_seq_from_fasta.pl', $interval_path, $pick_path );
is( $legacy_status, 0, 'legacy interval command remains available' );
is( $legacy_error,  '', 'legacy interval command emits no errors' );
is( $legacy_output, $expected_pick, 'legacy command delegates to identical behavior' );

my ( $pick_stdin_status, $pick_stdin_output, $pick_stdin_error ) = run_command(
    "chr1 1 1 +\n", $^X, 'pick_seq_from_fasta_neo.pl',
    '--fa', $interval_path, '--stdin',
);
is( $pick_stdin_status, 0, 'interval command accepts locations from standard input' );
is( $pick_stdin_error,  '', 'standard-input interval extraction emits no errors' );
is( $pick_stdin_output, ">chr1:1-1(+)\nA\n", 'single-base interval is correct' );

for my $bad_interval (
    [ "chr1 1 20 +\n", qr/exceeds sequence length/, 'out-of-bounds interval' ],
    [ "chr1 1 2 x\n", qr/Invalid strand/, 'invalid strand' ],
    [ "missing 1 2 +\n", qr/Unknown FASTA ID/, 'unknown FASTA ID' ],
) {
    my ( $status, $output, $error ) = run_command(
        $bad_interval->[0], $^X, 'pick_seq_from_fasta_neo.pl',
        '--fa', $interval_path, '--stdin',
    );
    isnt( $status, 0, "$bad_interval->[2] is rejected" );
    is( $output, '', "$bad_interval->[2] produces no sequence output" );
    like( $error, $bad_interval->[1], "$bad_interval->[2] has a clear error" );
}

my $location_path = path_for('locations.txt');
write_text(
    $location_path,
    "NC_000001.11:1-75\tsample.chr1(-1):5-2\n",
);
my ( $links_status, $links_output, $links_error ) = run_command(
    undef, $^X, 'links2fasta.pl', '--fa', $interval_path,
    '--in', $location_path,
);
is( $links_status, 0, 'compact location extraction exits successfully' );
is( $links_error,  '', 'compact location extraction emits no errors' );
is(
    $links_output,
    ">NC_000001.11:1-75\n" . ( 'A' x 70 ) . "\nAAAAA\n"
      . ">sample.chr1(-1):5-2\nYACG\n",
    'compact locations preserve dotted IDs, resolve prefixes, wrap output, and normalize coordinates',
);

my $gzip_location_path = path_for('locations.txt.gz');
my $normalized_location_path = path_for('location-output.fa.gz');
write_gzip( $gzip_location_path, read_text($location_path) );
is(
    system(
        'bin/perbool', 'fasta', 'extract-locations', '--fa', $interval_path,
        '--locations', $gzip_location_path, '--out', $normalized_location_path,
    ),
    0,
    'normalized compact extraction supports gzip list and output files',
);
is(
    read_gzip($normalized_location_path),
    $links_output,
    'normalized and legacy compact extraction agree',
);

my ( $bad_location_status, $bad_location_output, $bad_location_error ) =
  run_command(
    "chr1:0-2\n", $^X, 'links2fasta.pl', '--fa', $interval_path, '--stdin',
  );
isnt( $bad_location_status, 0, 'invalid compact coordinates are rejected' );
is( $bad_location_output, '', 'invalid compact coordinates produce no sequence output' );
like(
    $bad_location_error,
    qr/start must be a positive integer/,
    'invalid compact coordinates have a clear error',
);

my $late_bad_intervals = path_for('late-bad-intervals.txt');
my $late_bad_locations = path_for('late-bad-locations.txt');
my $preserved_interval_output = path_for('preserved-interval.fa');
my $preserved_location_output = path_for('preserved-location.fa');
write_text( $late_bad_intervals, "chr1 1 2 +\nmissing 1 2 +\n" );
write_text( $late_bad_locations, "chr1:1-2\nmissing:1-2\n" );
write_text( $preserved_interval_output, "preserved interval output\n" );
write_text( $preserved_location_output, "preserved location output\n" );
isnt(
    system(
        'bin/perbool', 'fasta', 'extract-intervals', '--fa', $interval_path,
        '--in', $late_bad_intervals, '--out', $preserved_interval_output,
    ),
    0,
    'interval extraction rejects a bad later interval',
);
is(
    read_text($preserved_interval_output),
    "preserved interval output\n",
    'failed interval extraction preserves existing output',
);
isnt(
    system(
        'bin/perbool', 'fasta', 'extract-locations', '--fa', $interval_path,
        '--in', $late_bad_locations, '--out', $preserved_location_output,
    ),
    0,
    'compact extraction rejects a bad later location',
);
is(
    read_text($preserved_location_output),
    "preserved location output\n",
    'failed compact extraction preserves existing output',
);

done_testing();
