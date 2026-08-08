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

my $counts =
    "ACGT\t5\n"
  . "acgt\t2\n"
  . "ACGTAA\t3\n"
  . "ACGTAAA\t4\n"
  . "ACGTAAAA\t5\n"
  . "ACGTAAAT\t6\n"
  . "ACGTAATT\t7\n"
  . "ACGTA\t8\n"
  . "NN\t9\n"
  . "NNaa\t10\n"
  . "NNA\t11\n"
  . "\n";
my $fasta =
  ">mir1 description\nac\ngt\n" . ">mir2\n" . "nn\n" . ">mir3\nACGTAA\n";
my $expected =
  ">mir1 description\t7\t18\n>mir2\t9\t10\n>mir3\t3\t5\n";
my $counts_gzip = path_for('counts.tsv.gz');
my $fasta_gzip = path_for('references.fa.gz');
write_gzip( $counts_gzip, $counts );
write_gzip( $fasta_gzip, $fasta );

my ( $status, $output, $error ) = run_command(
    undef, 'bin/perbool', 'small-rna', 'tail-counts',
    '--counts', $counts_gzip, '--fasta', $fasta_gzip,
);
is( $status, 0, 'normalized small-RNA tail counting exits successfully' );
is( $error, '', 'normalized small-RNA tail counting emits no errors' );
is(
    $output,
    $expected,
    'tail counting supports gzip, multiline and nested references, duplicate reads, case normalization, and suffix thresholds',
);

my $counts_path = path_for('counts.tsv');
my $fasta_path = path_for('references.fa');
write_text( $counts_path, $counts );
write_text( $fasta_path, $fasta );
my ( $legacy_status, $legacy_output, $legacy_error ) =
  run_command( undef, $^X, 'mirna_count.pl', $counts_path, $fasta_path );
is( $legacy_status, 0, 'legacy miRNA count syntax remains available' );
is( $legacy_error, '', 'legacy miRNA count emits no errors' );
is( $legacy_output, $expected, 'legacy and normalized tail counts agree' );

my ( $stdin_status, $stdin_output, $stdin_error ) = run_command(
    $counts, 'bin/perbool', 'small-rna', 'tail-counts',
    '--counts', '-', '--fasta', $fasta_path,
);
is( $stdin_status, 0, 'read counts can be supplied on standard input' );
is( $stdin_error, '', 'standard-input tail counting emits no errors' );
is( $stdin_output, $expected, 'standard-input and file results agree' );

for my $invalid (
    [ "ACGT\t1\nACGTAA\t-1\n", qr/nonnegative integer/, 'negative count' ],
    [ "ACGT\t1\textra\n", qr/exactly 2/, 'extra count field' ],
    [ "\t1\n", qr/Empty read sequence/, 'empty read sequence' ],
) {
    my ( $bad_status, $bad_output, $bad_error ) = run_command(
        $invalid->[0], 'bin/perbool', 'small-rna', 'tail-counts',
        '--counts', '-', '--fasta', $fasta_path,
    );
    isnt( $bad_status, 0, "$invalid->[2] is rejected" );
    is( $bad_output, '', "$invalid->[2] produces no partial output" );
    like( $bad_error, $invalid->[1], "$invalid->[2] error is clear" );
}

my $bad_fasta_path = path_for('bad.fa');
write_text( $bad_fasta_path, ">first\nACGT\n>empty\n" );
my ( $bad_fasta_status, $bad_fasta_output, $bad_fasta_error ) = run_command(
    $counts, 'bin/perbool', 'small-rna', 'tail-counts',
    '--counts', '-', '--fasta', $bad_fasta_path,
);
isnt( $bad_fasta_status, 0, 'malformed FASTA is rejected' );
is( $bad_fasta_output, '', 'malformed FASTA produces no partial output' );
like( $bad_fasta_error, qr/Empty FASTA sequence/, 'malformed FASTA error is clear' );

my ( $stdin_conflict_status, $stdin_conflict_output, $stdin_conflict_error ) =
  run_command(
    '', 'bin/perbool', 'small-rna', 'tail-counts',
    '--counts', '-', '--fasta', '-',
  );
isnt( $stdin_conflict_status, 0, 'two standard-input sources are rejected' );
is( $stdin_conflict_output, '', 'standard-input conflict produces no output' );
like( $stdin_conflict_error, qr/Only one input/, 'standard-input conflict is clear' );

done_testing();
