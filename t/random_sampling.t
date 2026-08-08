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

sub run_with_stdin {
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

my $input_content =
    "\@dup first\nAAA\n+dup first\nIII\n"
  . "\@dup second\nCCC\n+\nJJJ\n"
  . "\@last\nGGG\n+\nKKK\n";

my $input_path  = path_for('input.fq');
my $unique_path = path_for('unique.fq');
write_text( $input_path, $input_content );

is(
    system(
        $^X, 'fastq_randomsampling.pl', '--in', $input_path,
        '--out', $unique_path, '--quantity', 3,
        '--without-replacement', '--seed', 11,
    ),
    0,
    'sampling all records without replacement exits successfully',
);
is(
    read_text($unique_path),
    "\@dup:1 first\nAAA\n+dup:1 first\nIII\n"
      . "\@dup:2 second\nCCC\n+\nJJJ\n"
      . "\@last:3\nGGG\n+\nKKK\n",
    'duplicate IDs remain distinct and the final bare-ID record is retained',
);

my $seeded_path1 = path_for('seeded-1.fq');
my $seeded_path2 = path_for('seeded-2.fq');
for my $output_path ( $seeded_path1, $seeded_path2 ) {
    is(
        system(
            $^X, 'fastq_randomsampling.pl', '--in', $input_path,
            '--out', $output_path, '--quantity', 10, '--seed', 42,
        ),
        0,
        'sampling with replacement exits successfully',
    );
}
is(
    read_text($seeded_path1),
    read_text($seeded_path2),
    'the same random seed produces identical output',
);
my @sampled_lines = split /\n/, read_text($seeded_path1);
is( scalar @sampled_lines, 40, 'sampling with replacement emits 10 records' );
for my $record_number ( 1 .. 10 ) {
    like(
        $sampled_lines[ ( $record_number - 1 ) * 4 ],
        qr/^\@(?:dup|last):$record_number(?:\s|$)/,
        "sampled record $record_number has a valid, numbered FASTQ header",
    );
}

isnt(
    system(
        $^X, 'fastq_randomsampling.pl', '--in', $input_path,
        '--out', path_for('too-many.fq'), '--quantity', 4,
        '--without-replacement',
    ),
    0,
    'sampling too many records without replacement is rejected',
);

my $gzip_input  = path_for('input.fq.gz');
my $gzip_output = path_for('output.fq.gz');
write_gzip( $gzip_input, $input_content );
is(
    system(
        $^X, 'fastq_randomsampling.pl', '--in', $gzip_input,
        '--out', $gzip_output, '--quantity', 3,
        '--without-replacement', '--seed', 11,
    ),
    0,
    'two-pass sampling supports gzip input and output',
);
is(
    read_gzip($gzip_output),
    read_text($unique_path),
    'gzip sampling output matches plain FASTQ output',
);

my $normalized_path = path_for('normalized.fq');
is(
    system(
        'bin/perbool', 'fastq', 'sample', '--in', $input_path,
        '--out', $normalized_path, '--quantity', 3,
        '--without-replacement', '--seed', 11,
    ),
    0,
    'normalized sampling command exits successfully',
);
is(
    read_text($normalized_path),
    read_text($unique_path),
    'normalized and legacy sampling interfaces agree',
);

my ( $stdin_status, $stdin_output, $stdin_error ) = run_with_stdin(
    $input_content, 'bin/perbool', 'fastq', 'sample', '--in', '-', '--out', '-',
    '--quantity', 3, '--without-replacement', '--seed', 11,
);
is( $stdin_status, 0, 'sampling accepts FASTQ from standard input' );
is( $stdin_error, '', 'standard-input sampling emits no errors' );
is( $stdin_output, read_text($unique_path), 'standard-input sampling is correct' );

my $broken_path = path_for('broken.fq');
write_text( $broken_path, "\@broken\nACGT\n+\nIII\n" );
isnt(
    system(
        $^X, 'fastq_randomsampling.pl', '--in', $broken_path,
        '--out', path_for('broken.out.fq'), '--quantity', 1,
    ),
    0,
    'invalid sequence and quality lengths are rejected before sampling',
);

my $late_broken_path = path_for('late-broken.fq');
my $preserved_path = path_for('preserved.fq');
write_text(
    $late_broken_path,
    "\@valid\nACGT\n+\nIIII\n\@broken\nACGT\n+\nIII\n",
);
write_text( $preserved_path, "preserved sampled output\n" );
isnt(
    system(
        'bin/perbool', 'fastq', 'sample', '--in', $late_broken_path,
        '--out', $preserved_path, '--quantity', 1, '--seed', 3,
    ),
    0,
    'sampling rejects a malformed later record',
);
is(
    read_text($preserved_path),
    "preserved sampled output\n",
    'failed sampling preserves an existing output file',
);

done_testing();
