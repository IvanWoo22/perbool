use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use IO::Zlib;
use IPC::Open3;
use Symbol qw(gensym);
use Test::More;

use lib 'lib';
use Perbool::Fastq qw(
  fastq_id paired_fastq_id quality_text read_fastq_record sequence_text
  write_fastq_record
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
    print {$child_in} $input;
    close $child_in;
    my $stdout_text = do { local $/; <$child_out> };
    my $stderr_text = do { local $/; <$stderr> };
    waitpid $pid, 0;
    return ( $?, $stdout_text, $stderr_text );
}

my $input_content =
    "\@read1 alpha\nAAA\n+\nIII\n"
  . "\@read2 beta\nCCC\n+\nJJJ\n"
  . "\@read3\nGGG\n+\nKKK\n";

open my $scalar_in, '<', \$input_content;
my $first_record = read_fastq_record( $scalar_in, 1 );
is( fastq_id($first_record), 'read1', 'shared parser extracts the read ID' );
is( sequence_text($first_record), 'AAA', 'shared parser returns sequence text' );
is( quality_text($first_record), 'III', 'shared parser returns quality text' );
is(
    paired_fastq_id($first_record),
    'read1',
    'paired ID normalization leaves an unsuffixed ID unchanged',
);
my %suffixed_record = ( %{$first_record}, header => "\@read1/1 alpha\n" );
is(
    paired_fastq_id(\%suffixed_record),
    'read1',
    'paired ID normalization removes a slash mate suffix',
);
my $scalar_output = '';
open my $scalar_out, '>', \$scalar_output;
write_fastq_record( $scalar_out, $first_record );
close $scalar_out;
is(
    $scalar_output,
    "\@read1 alpha\nAAA\n+\nIII\n",
    'shared writer preserves a FASTQ record exactly',
);

my $invalid_content = "\@bad\nACGT\n+\nIII\n";
open my $invalid_fh, '<', \$invalid_content;
my $error = '';
eval { read_fastq_record( $invalid_fh, 1 ) };
$error = $@;
like(
    $error,
    qr/Sequence and quality lengths differ/,
    'shared parser rejects sequence and quality length mismatches',
);

my ( $fasta_status, $fasta_output, $fasta_error ) =
  run_with_stdin( $input_content, $^X, 'fastq2fasta.pl' );
is( $fasta_status, 0, 'FASTQ-to-FASTA conversion exits successfully' );
is( $fasta_error,  '', 'FASTQ-to-FASTA conversion emits no errors' );
is(
    $fasta_output,
    ">read1 alpha\nAAA\n>read2 beta\nCCC\n>read3\nGGG\n",
    'FASTQ-to-FASTA conversion preserves IDs, descriptions, and sequences',
);

my $count_input =
    "\@one\nCCC\n+\nIII\n"
  . "\@two\nAAA\n+\nIII\n"
  . "\@three\nCCC\n+\nIII\n";
my ( $count_status, $count_output, $count_error ) =
  run_with_stdin( $count_input, $^X, 'fastq2count.pl' );
is( $count_status, 0, 'FASTQ sequence counting exits successfully' );
is( $count_error,  '', 'FASTQ sequence counting emits no errors' );
is(
    $count_output,
    "AAA\t1\nCCC\t2\n",
    'FASTQ sequence counts are deterministic and sorted',
);

my $input_path  = path_for('input.fq');
my $names_path  = path_for('names.txt');
my $fetch_path  = path_for('fetched.fq');
my $delete_path = path_for('deleted.fq');
write_text( $input_path, $input_content );
write_text( $names_path, "\@read2 beta\nread3\n\n" );

isnt(
    system(
        $^X, 'fetch_fastq.pl', '--name', $names_path,
        '--in', $input_path, '--out', $input_path,
    ),
    0,
    'read extraction rejects identical input and output paths',
);
is(
    read_text($input_path),
    $input_content,
    'same-path rejection leaves the input FASTQ unchanged',
);

is(
    system(
        $^X, 'fetch_fastq.pl', '--name', $names_path,
        '--in', $input_path, '--out', $fetch_path,
    ),
    0,
    'read extraction exits successfully',
);
is(
    read_text($fetch_path),
    "\@read2 beta\nCCC\n+\nJJJ\n\@read3\nGGG\n+\nKKK\n",
    'read extraction accepts IDs, full headers, and blank list lines',
);

is(
    system(
        $^X, 'delete_fastq.pl', '--name', $names_path,
        '--in', $input_path, '--out', $delete_path,
    ),
    0,
    'read deletion exits successfully',
);
is(
    read_text($delete_path),
    "\@read1 alpha\nAAA\n+\nIII\n",
    'read deletion is complementary to extraction',
);

my $gzip_input  = path_for('input.fq.gz');
my $gzip_output = path_for('fetched.fq.gz');
write_gzip( $gzip_input, $input_content );
is(
    system(
        $^X, 'fetch_fastq.pl', '--name', $names_path,
        '--in', $gzip_input, '--out', $gzip_output,
    ),
    0,
    'shared I/O supports gzip extraction',
);
is(
    read_gzip($gzip_output),
    read_text($fetch_path),
    'gzip extraction matches plain FASTQ extraction',
);

my ( $broken_status, undef, $broken_error ) =
  run_with_stdin( $invalid_content, $^X, 'fastq2fasta.pl' );
isnt( $broken_status, 0, 'conversion rejects malformed FASTQ input' );
like(
    $broken_error,
    qr/Sequence and quality lengths differ/,
    'conversion reports the malformed record clearly',
);

done_testing();
