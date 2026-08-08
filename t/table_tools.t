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

my $left_content = "alpha\nshared\n\nregex[1]\n";
my $right_content = "shared\nshared\nmissing\nregex[1]\n\n";
my $left_path = path_for('left.txt');
my $right_path = path_for('right.txt');
my $left_gzip_path = path_for('left.txt.gz');
write_text( $left_path, $left_content );
write_text( $right_path, $right_content );
write_gzip( $left_gzip_path, $left_content );

my ( $intersect_status, $intersect_output, $intersect_error ) = run_command(
    undef, 'bin/perbool', 'table', 'intersect-lines',
    '--left', $left_gzip_path, '--right', $right_path,
);
is( $intersect_status, 0, 'normalized line intersection exits successfully' );
is( $intersect_error,  '', 'line intersection emits no errors' );
is(
    $intersect_output,
    "shared\nshared\nregex[1]\n\n",
    'intersection is exact, supports gzip, retains blank lines and right-side duplicates/order',
);

my ( $unique_status, $unique_output, $unique_error ) = run_command(
    undef, 'bin/perbool', 'table', 'intersect-lines',
    '--left', $left_path, '--right', $right_path, '--unique',
);
is( $unique_status, 0, 'unique line intersection exits successfully' );
is( $unique_error,  '', 'unique line intersection emits no errors' );
is( $unique_output, "shared\nregex[1]\n\n", '--unique emits each shared line once' );

my ( $legacy_intersect_status, $legacy_intersect_output, $legacy_intersect_error ) =
  run_command( undef, $^X, 'compare_file.pl', $left_path, $right_path );
is( $legacy_intersect_status, 0, 'legacy comparison syntax remains available' );
is( $legacy_intersect_error,  '', 'legacy comparison emits no errors' );
is( $legacy_intersect_output, $intersect_output, 'legacy and normalized intersections agree' );

my ( $stdin_conflict_status, $stdin_conflict_output, $stdin_conflict_error ) =
  run_command( '', 'bin/perbool', 'table', 'intersect-lines', '--left', '-', '--right', '-' );
isnt( $stdin_conflict_status, 0, 'two standard-input intersections are rejected' );
is( $stdin_conflict_output, '', 'standard-input conflict produces no output' );
like( $stdin_conflict_error, qr/Only one input/, 'standard-input conflict is clear' );

my $table1 = "b\tB1\t\na\tA1\tA2\n";
my $table2 = "c\tC1\nb\tB2\n";
my $table3 = "a\tA3\tA4\nc\tC3\tC4\n";
my $table1_path = path_for('table1.tsv');
my $table2_gzip_path = path_for('table2.tsv.gz');
my $table3_path = path_for('table3.tsv');
write_text( $table1_path, $table1 );
write_gzip( $table2_gzip_path, $table2 );
write_text( $table3_path, $table3 );
my $expected_join =
    "a\tA1\tA2\tNA\tA3\tA4\n"
  . "b\tB1\t\tB2\tNA\tNA\n"
  . "c\tNA\tNA\tC1\tC3\tC4\n";

my ( $join_status, $join_output, $join_error ) = run_command(
    undef, 'bin/perbool', 'table', 'join',
    $table1_path, $table2_gzip_path, $table3_path,
);
is( $join_status, 0, 'normalized TSV join exits successfully' );
is( $join_error,  '', 'normalized TSV join emits no errors' );
is(
    $join_output,
    $expected_join,
    'full join is tab-strict, sorted, gzip-aware, and preserves empty cells',
);

my ( $legacy_join_status, $legacy_join_output, $legacy_join_error ) = run_command(
    undef, $^X, 'tsv_join.pl', $table1_path, $table2_gzip_path, $table3_path,
);
is( $legacy_join_status, 0, 'legacy TSV join syntax remains available' );
is( $legacy_join_error,  '', 'legacy TSV join emits no errors' );
is( $legacy_join_output, $expected_join, 'legacy and normalized TSV joins agree' );

my ( $stdin_join_status, $stdin_join_output, $stdin_join_error ) = run_command(
    $table2, 'bin/perbool', 'table', 'join', '--missing', '.',
    $table1_path, '-',
);
is( $stdin_join_status, 0, 'TSV join accepts one table from standard input' );
is( $stdin_join_error,  '', 'standard-input TSV join emits no errors' );
is(
    $stdin_join_output,
    "a\tA1\tA2\t.\nb\tB1\t\tB2\nc\t.\t.\tC1\n",
    'custom missing value and standard-input table are correct',
);

for my $invalid_table (
    [ "a\t1\nb\t2\t3\n", qr/Inconsistent column count/, 'inconsistent width' ],
    [ "a\t1\na\t2\n", qr/Duplicate key/, 'duplicate key' ],
    [ "key value\n", qr/key and at least one value/, 'space-delimited row' ],
) {
    my $bad_path = path_for( 'bad-' . $invalid_table->[2] . '.tsv' );
    write_text( $bad_path, $invalid_table->[0] );
    my ( $status, $output, $error ) =
      run_command( undef, $^X, 'tsv_join.pl', $table1_path, $bad_path );
    isnt( $status, 0, "$invalid_table->[2] is rejected" );
    is( $output, '', "$invalid_table->[2] produces no partial join" );
    like( $error, $invalid_table->[1], "$invalid_table->[2] error is clear" );
}

my $extract_content =
    "x\tmeta:id[ABC_12;rest\tz\r\n"
  . "y\tid[DEF99-tail\tq\r\n";
my $extract_path = path_for('extract.tsv.gz');
write_gzip( $extract_path, $extract_content );
my $expected_extract = "x\tABC_12\tz\ny\tDEF99\tq\n";

my ( $extract_status, $extract_output, $extract_error ) = run_command(
    undef, 'bin/perbool', 'table', 'extract-after',
    '--column', 2, '--prefix', 'id[', '--in', $extract_path,
);
is( $extract_status, 0, 'normalized column extraction exits successfully' );
is( $extract_error,  '', 'column extraction emits no errors' );
is(
    $extract_output,
    $expected_extract,
    'column extraction treats metacharacter prefix literally and supports gzip/CRLF',
);

my ( $legacy_extract_status, $legacy_extract_output, $legacy_extract_error ) =
  run_command( $extract_content, $^X, 'format_column_name.pl', 2, 'id[' );
is( $legacy_extract_status, 0, 'legacy column extraction syntax remains available' );
is( $legacy_extract_error,  '', 'legacy column extraction emits no errors' );
is( $legacy_extract_output, $expected_extract, 'legacy and normalized extraction agree' );

for my $invalid_extract (
    [ "x\tone\n", [ '--column', 3, '--prefix', 'id[' ], qr/Missing column 3/, 'missing column' ],
    [ "x\tnone\n", [ '--column', 2, '--prefix', 'id[' ], qr/Prefix .* not found/, 'missing prefix' ],
    [ "x\tid[;\n", [ '--column', 2, '--prefix', 'id[' ], qr/No word suffix/, 'missing suffix' ],
) {
    my ( $status, $output, $error ) = run_command(
        $invalid_extract->[0], $^X, 'format_column_name.pl',
        @{ $invalid_extract->[1] },
    );
    isnt( $status, 0, "$invalid_extract->[3] is rejected" );
    is( $output, '', "$invalid_extract->[3] produces no output" );
    like( $error, $invalid_extract->[2], "$invalid_extract->[3] error is clear" );
}

my $duplicate_content =
    "a\n"
  . ( "b\n" x 2 )
  . ( "\n" x 3 )
  . ( "c\n" x 4 )
  . ( "d\n" x 6 )
  . ( "e\n" x 11 )
  . ( "f\n" x 51 )
  . ( "g\n" x 101 )
  . ( "h\n" x 301 );
my $duplicate_gzip_path = path_for('duplicates.txt.gz');
write_gzip( $duplicate_gzip_path, $duplicate_content );
my $expected_bins =
    "1:\t1\n"
  . "2-3:\t2\n"
  . "4-5:\t1\n"
  . "6-10:\t1\n"
  . "11-50:\t1\n"
  . "51-100:\t1\n"
  . "101-300:\t1\n"
  . ">300:\t1\n";

my ( $bins_status, $bins_output, $bins_error ) = run_command(
    undef, 'bin/perbool', 'table', 'count-duplicates',
    '--in', $duplicate_gzip_path,
);
is( $bins_status, 0, 'normalized duplicate binning exits successfully' );
is( $bins_error,  '', 'duplicate binning emits no errors' );
is( $bins_output, $expected_bins, 'all occurrence bins and blank-line values are correct' );

my ( $legacy_bins_status, $legacy_bins_output, $legacy_bins_error ) =
  run_command( $duplicate_content, $^X, 'count_duplication.pl' );
is( $legacy_bins_status, 0, 'legacy duplicate binning syntax remains available' );
is( $legacy_bins_error,  '', 'legacy duplicate binning emits no errors' );
is( $legacy_bins_output, $expected_bins, 'legacy and normalized duplicate bins agree' );

done_testing();
