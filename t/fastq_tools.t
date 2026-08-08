use strict;
use warnings;

use File::Path qw(make_path);
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
    while ( my $line = <$fh> ) {
        $content .= $line;
    }
    close $fh;
    return $content;
}

my $single_in  = path_for('single.fq');
my $single_out = path_for('single.filtered.fq');
write_text(
    $single_in,
    "\@keep\nACGT\n+\nIIII\n\@drop\nACGTA\n+\nIIIII\n",
);
is(
    system(
        $^X, 'filter_fastq.pl', '--in', $single_in, '--out', $single_out,
        '-m', 4, '-M', 4,
    ),
    0,
    'single-end length filter exits successfully',
);
is(
    read_text($single_out),
    "\@keep\nACGT\n+\nIIII\n",
    'single-end filter uses biological sequence length without the newline',
);

my $normalized_single_out = path_for('normalized.single.filtered.fq');
is(
    system(
        'bin/perbool', 'fastq', 'filter', '--in', $single_in,
        '--out', $normalized_single_out, '--min', 4, '--max', 4,
    ),
    0,
    'normalized single-end filter exits successfully',
);
is( read_text($normalized_single_out), read_text($single_out), 'normalized and legacy filters agree' );

my $long_in      = path_for('long.fq');
my $long_out     = path_for('long.filtered.fq');
my $long_record  = "\@long\n" . ( 'A' x 1001 ) . "\n+\n" . ( 'I' x 1001 ) . "\n";
write_text( $long_in, $long_record );
is(
    system(
        $^X, 'filter_fastq.pl', '--in', $long_in, '--out', $long_out,
    ),
    0,
    'single-end filter accepts input without an explicit maximum',
);
is(
    read_text($long_out),
    $long_record,
    'reads longer than 1000 bp are not silently dropped by default',
);

my $r1_in  = path_for('r1.fq');
my $r2_in  = path_for('r2.fq');
my $prefix = path_for('paired.filtered');
write_text(
    $r1_in,
    "\@pair1/1\nACGT\n+\nIIII\n\@pair2/1\nACGTA\n+\nIIIII\n",
);
write_text(
    $r2_in,
    "\@pair1/2\nTGCA\n+\nIIII\n\@pair2/2\nTGCA\n+\nIIII\n",
);
is(
    system(
        $^X, 'filter_pfastq.pl', '-1', $r1_in, '-2', $r2_in,
        '--out', $prefix, '--min', 4, '--max', 4,
    ),
    0,
    'paired-end length filter exits successfully',
);
is(
    read_text( $prefix . '_R1.fq' ),
    "\@pair1/1\nACGT\n+\nIIII\n",
    'paired filter retains R1 only when both reads meet the boundary',
);
is(
    read_text( $prefix . '_R2.fq' ),
    "\@pair1/2\nTGCA\n+\nIIII\n",
    'paired filter keeps R2 synchronized with R1',
);

my $normalized_prefix = path_for('normalized.paired.filtered');
is(
    system(
        'bin/perbool', 'fastq', 'filter-paired', '--r1', $r1_in,
        '--r2', $r2_in, '--out', $normalized_prefix,
        '--min', 4, '--max', 4,
    ),
    0,
    'normalized paired-end filter exits successfully',
);
is(
    read_text( $normalized_prefix . '_R1.fq' ),
    read_text( $prefix . '_R1.fq' ),
    'normalized paired R1 output agrees with legacy output',
);
is(
    read_text( $normalized_prefix . '_R2.fq' ),
    read_text( $prefix . '_R2.fq' ),
    'normalized paired R2 output agrees with legacy output',
);

my $gzip_prefix = path_for('paired.gzip');
is(
    system(
        $^X, 'filter_pfastq.pl', '-1', $r1_in, '-2', $r2_in,
        '--out', $gzip_prefix, '--min', 4, '--max', 4, '--gzip',
    ),
    0,
    'paired-end filter writes gzip output successfully',
);
is(
    read_gzip( $gzip_prefix . '_R1.fq.gz' ),
    "\@pair1/1\nACGT\n+\nIIII\n",
    'gzip R1 output contains the filtered record',
);
is(
    read_gzip( $gzip_prefix . '_R2.fq.gz' ),
    "\@pair1/2\nTGCA\n+\nIIII\n",
    'gzip R2 output remains synchronized',
);

my $mismatch_r1 = path_for('mismatch.r1.fq');
my $mismatch_r2 = path_for('mismatch.r2.fq');
write_text(
    $mismatch_r1,
    "\@pair1/1\nACGT\n+\nIIII\n\@first/1\nACGT\n+\nIIII\n",
);
write_text(
    $mismatch_r2,
    "\@pair1/2\nTGCA\n+\nIIII\n\@second/2\nTGCA\n+\nIIII\n",
);
my $mismatch_prefix = path_for('mismatch');
write_text( $mismatch_prefix . '_R1.fq', "preserved R1\n" );
write_text( $mismatch_prefix . '_R2.fq', "preserved R2\n" );
isnt(
    system(
        $^X, 'filter_pfastq.pl', '-1', $mismatch_r1, '-2', $mismatch_r2,
        '--out', $mismatch_prefix,
    ),
    0,
    'paired filter rejects mismatched read IDs',
);
is( read_text( $mismatch_prefix . '_R1.fq' ), "preserved R1\n", 'paired failure preserves R1' );
is( read_text( $mismatch_prefix . '_R2.fq' ), "preserved R2\n", 'paired failure preserves R2' );

my $kmer_in  = path_for('kmer.fq');
my $kmer_out = path_for('kmer.out.fq');
write_text(
    $kmer_in,
    "\@read1 description\nACGTACGTAA\n+read1 description\nJJJJJJJJJJ\n",
);
is(
    system(
        $^X, 'fastqKmer.pl', '--in', $kmer_in, '--out', $kmer_out,
        '--kmer', 4, '--step', 3,
    ),
    0,
    'K-mer splitting with an explicit step exits successfully',
);
is(
    read_text($kmer_out),
    "\@read1_0 description\nACGT\n+\nJJJJ\n"
      . "\@read1_1 description\nTACG\n+\nJJJJ\n"
      . "\@read1_2 description\nGTAA\n+\nJJJJ\n",
    'K-mer splitting appends the terminal window exactly once',
);

my $default_in  = path_for('default-step.fq');
my $default_out = path_for('default-step.out.fq');
write_text( $default_in, "\@read2\nACGTA\n+\nIIIII\n" );
is(
    system(
        $^X, 'fastqKmer.pl', '--in', $default_in, '--out', $default_out,
        '--kmer', 3,
    ),
    0,
    'K-mer splitting defaults to a one-base step',
);
is(
    read_text($default_out),
    "\@read2_0\nACG\n+\nIII\n"
      . "\@read2_1\nCGT\n+\nIII\n"
      . "\@read2_2\nGTA\n+\nIII\n",
    'default step emits all sliding windows without corrupting a bare read ID',
);

my $normalized_kmer_input = path_for('normalized-kmer.fq.gz');
my $normalized_kmer_output = path_for('normalized-kmer.out.fq.gz');
write_gzip( $normalized_kmer_input, read_text($kmer_in) );
is(
    system(
        'bin/perbool', 'fastq', 'split-kmers', '--in', $normalized_kmer_input,
        '--out', $normalized_kmer_output, '--kmer', 4, '--step', 3,
    ),
    0,
    'normalized K-mer splitting supports gzip input and output',
);
is(
    read_gzip($normalized_kmer_output),
    read_text($kmer_out),
    'normalized and legacy K-mer splitting agree',
);

my $paired_source = path_for('long-read.fq');
my $left_out = path_for('left.fq');
my $right_out = path_for('right.fq');
my $paired_source_content =
    "\@long description\nAAACCGTA\n+long description\n12345678\n"
  . "\@bare\nACGT\n+\nIIII\n";
write_text( $paired_source, $paired_source_content );
is(
    system(
        $^X, 'singled2paired.pl', '--in', $paired_source, '--length', 3,
        '--R1', $left_out, '--R2', $right_out,
    ),
    0,
    'single-to-paired conversion exits successfully',
);
is(
    read_text($left_out),
    "\@long 1 description\nAAA\n+\n123\n"
      . "\@bare 1\nACG\n+\nIII\n",
    'left output contains the first bases and qualities with valid headers',
);
is(
    read_text($right_out),
    "\@long 2 description\nTAC\n+\n876\n"
      . "\@bare 2\nACG\n+\nIII\n",
    'right output reverse-complements sequence and reverses quality',
);

my $r1_directory = path_for('normalized-r1');
my $r2_directory = path_for('normalized-r2');
make_path( $r1_directory, $r2_directory );
my $normalized_r1 = File::Spec->catfile( $r1_directory, 'reads.fq.gz' );
my $normalized_r2 = File::Spec->catfile( $r2_directory, 'reads.fq.gz' );
my $paired_gzip_input = path_for('long-read.fq.gz');
write_gzip( $paired_gzip_input, $paired_source_content );
is(
    system(
        'bin/perbool', 'fastq', 'single-to-paired', '--in', $paired_gzip_input,
        '--length', 3, '--r1', $normalized_r1, '--r2', $normalized_r2,
    ),
    0,
    'normalized single-to-paired supports gzip and separate output directories',
);
is( read_gzip($normalized_r1), read_text($left_out), 'normalized R1 agrees with legacy R1' );
is( read_gzip($normalized_r2), read_text($right_out), 'normalized R2 agrees with legacy R2' );
isnt(
    system(
        $^X, 'singled2paired.pl', '--in', $paired_source, '--length', 3,
        '--R1', path_for('same.fq'), '--R2', path_for('same.fq'),
    ),
    0,
    'single-to-paired conversion rejects identical output paths',
);
isnt(
    system(
        $^X, 'singled2paired.pl', '--in', $paired_source, '--length', 0,
        '--R1', path_for('zero.R1.fq'), '--R2', path_for('zero.R2.fq'),
    ),
    0,
    'single-to-paired conversion rejects a zero read length',
);

isnt(
    system(
        $^X, 'fastqKmer.pl', '--in', $default_in, '--out', path_for('bad.fq'),
        '--kmer', 3, '--step', 0,
    ),
    0,
    'zero K-mer step is rejected instead of looping forever',
);

my $broken_in = path_for('broken.fq');
write_text(
    $broken_in,
    "\@valid\nACGT\n+\nIIII\n\@broken\nACGT\n+\nIII\n",
);
my $broken_out = path_for('broken.out.fq');
write_text( $broken_out, "preserved filtered output\n" );
isnt(
    system(
        $^X, 'filter_fastq.pl', '--in', $broken_in,
        '--out', $broken_out,
    ),
    0,
    'sequence and quality length mismatch is rejected',
);
is( read_text($broken_out), "preserved filtered output\n", 'failed filter preserves existing output' );

my $broken_kmer_out = path_for('broken-kmer.out.fq');
write_text( $broken_kmer_out, "preserved K-mer output\n" );
isnt(
    system(
        'bin/perbool', 'fastq', 'split-kmers', '--in', $broken_in,
        '--out', $broken_kmer_out, '--kmer', 3,
    ),
    0,
    'K-mer splitting rejects a malformed later record',
);
is(
    read_text($broken_kmer_out),
    "preserved K-mer output\n",
    'failed K-mer splitting preserves existing output',
);

my $broken_r1 = path_for('broken-paired.R1.fq');
my $broken_r2 = path_for('broken-paired.R2.fq');
write_text( $broken_r1, "preserved converted R1\n" );
write_text( $broken_r2, "preserved converted R2\n" );
isnt(
    system(
        'bin/perbool', 'fastq', 'single-to-paired', '--in', $broken_in,
        '--length', 3, '--r1', $broken_r1, '--r2', $broken_r2,
    ),
    0,
    'single-to-paired rejects a malformed later record',
);
is( read_text($broken_r1), "preserved converted R1\n", 'failed conversion preserves R1' );
is( read_text($broken_r2), "preserved converted R2\n", 'failed conversion preserves R2' );

done_testing();
