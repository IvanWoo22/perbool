use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use IO::Zlib;
use IPC::Open3;
use Symbol qw(gensym);
use Test::More;

use lib 'lib';
use Perbool::IntervalSet;

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

my $set = Perbool::IntervalSet->new;
$set->add_range( 10, 12 )->add_range( 20, 21 )->add_range( 13, 15 );
is( $set->as_string, '10-15,20-21', 'adjacent integer ranges are merged' );
is( $set->cardinality, 8, 'interval cardinality counts merged members' );
is( $set->at(1),   10, 'positive indexing starts at the smallest member' );
is( $set->at(6),   15, 'positive indexing crosses a merged range' );
is( $set->at(7),   20, 'positive indexing crosses a gap' );
is( $set->at(-1),  21, 'negative indexing starts at the largest member' );
is( $set->at(-8),  10, 'negative indexing reaches the smallest member' );
ok( !defined $set->at(0), 'zero is not a valid interval index' );
ok( !defined $set->at(9), 'out-of-range interval index returns undef' );

my $bed_set = Perbool::IntervalSet->new;
$bed_set->add_bed_range( 0, 3 )->add_bed_range( 3, 5 );
is( $bed_set->as_string, '1-5', 'BED half-open ranges become 1-based inclusive ranges' );

my $bed_content =
    "chr2\t4\t6\n"
  . "chr1\t0\t3\tname\n"
  . "chr1\t2\t5\n"
  . "chr:odd\t9\t10\n";
my $bed_path = path_for('ranges.bed.gz');
write_gzip( $bed_path, $bed_content );
my $expected_yaml =
    "---\n"
  . '"chr1": 1-5' . "\n"
  . '"chr2": 5-6' . "\n"
  . '"chr:odd": 10' . "\n";

my ( $bed_status, $bed_output, $bed_error ) = run_command(
    undef, 'bin/perbool', 'genome', 'bed-to-yaml', '--in', $bed_path,
);
is( $bed_status, 0, 'normalized BED conversion exits successfully' );
is( $bed_error, '', 'normalized BED conversion emits no errors' );
is( $bed_output, $expected_yaml, 'BED conversion merges, sorts, quotes, and converts coordinates' );

my $plain_bed_path = path_for('ranges.bed');
write_text( $plain_bed_path, $bed_content );
my ( $legacy_bed_status, $legacy_bed_output, $legacy_bed_error ) =
  run_command( undef, $^X, 'bed2yml.pl', $plain_bed_path );
is( $legacy_bed_status, 0, 'legacy BED entry point remains available' );
is( $legacy_bed_error, '', 'legacy BED entry point emits no errors' );
is( $legacy_bed_output, $expected_yaml, 'legacy and normalized BED conversion agree' );

my ( $bad_bed_status, $bad_bed_output, $bad_bed_error ) = run_command(
    "chr1\t0\t3\nchr2\t4\t4\n",
    'bin/perbool', 'genome', 'bed-to-yaml',
);
isnt( $bad_bed_status, 0, 'empty BED interval is rejected' );
is( $bad_bed_output, '', 'invalid BED produces no partial YAML' );
like( $bad_bed_error, qr/BED end must be greater/, 'invalid BED error is clear' );

my $range_content =
    "chr1\t100\t102\t+\tParent=transcript:tx_plus.1\n"
  . "chr1\t102\t104\t+\tID=e2;Parent=transcript:tx_plus.1\n"
  . "chr2\t500\t502\t-\tParent=transcript:tx_minus_2\n"
  . "chr2\t510\t511\t-\tParent=transcript:tx_minus_2\n"
  . "chr3\t1\t2\t+\tParent=transcript:multi-A,transcript:multi-B\n";
my $range_path = path_for('transcript-ranges.tsv.gz');
write_gzip( $range_path, $range_content );

for my $case (
    [ 'tx_plus.1', 1,  "chr1\t100\n", 'plus-strand first base' ],
    [ 'tx_plus.1', 4,  "chr1\t103\n", 'overlap is not counted twice' ],
    [ 'tx_minus_2', 1, "chr2\t511\n", 'minus-strand first base' ],
    [ 'tx_minus_2', 4, "chr2\t501\n", 'minus-strand indexing crosses a gap' ],
    [ 'multi-B', 2,     "chr3\t2\n",   'comma-separated Parent IDs' ],
) {
    my ( $status, $output, $error ) = run_command(
        undef, 'bin/perbool', 'genome', 'transcript-coordinate',
        '--transcript', $case->[0], '--position', $case->[1], '--in', $range_path,
    );
    is( $status, 0, "$case->[3] exits successfully" );
    is( $error, '', "$case->[3] emits no errors" );
    is( $output, $case->[2], "$case->[3] maps correctly" );
}

my ( $legacy_position_status, $legacy_position_output, $legacy_position_error ) =
  run_command( $range_content, $^X, 'coordinate_position.pl', 'tx_minus_2', 5 );
is( $legacy_position_status, 0, 'legacy transcript coordinate syntax remains available' );
is( $legacy_position_error, '', 'legacy transcript coordinate emits no errors' );
is( $legacy_position_output, "chr2\t500\n", 'legacy transcript coordinate is correct' );

for my $invalid (
    [ $range_content, 'missing', 1, qr/was not found/, 'unknown transcript' ],
    [ $range_content, 'tx_plus.1', 6, qr/exceeds the length/, 'position beyond transcript' ],
    [ "chr1\t1\t2\t+\tID=exon:1\n", 'tx', 1, qr/Missing Parent transcript/, 'missing transcript Parent' ],
    [ "chr1\t1\t2\t+\tParent=transcript:tx\nchr2\t3\t4\t+\tParent=transcript:tx\n", 'tx', 1, qr/multiple references/, 'inconsistent reference' ],
    [ "chr1\t1\t2\t+\tParent=transcript:tx\nchr1\t3\t4\t-\tParent=transcript:tx\n", 'tx', 1, qr/multiple strands/, 'inconsistent strand' ],
) {
    my ( $status, $output, $error ) = run_command(
        $invalid->[0], 'bin/perbool', 'genome', 'transcript-coordinate',
        '--transcript', $invalid->[1], '--position', $invalid->[2],
    );
    isnt( $status, 0, "$invalid->[4] is rejected" );
    is( $output, '', "$invalid->[4] produces no partial result" );
    like( $error, $invalid->[3], "$invalid->[4] error is clear" );
}

done_testing();
