use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use IO::Zlib;
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

done_testing();
