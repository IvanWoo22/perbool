use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use IO::Zlib;
use IPC::Open3;
use Symbol qw(gensym);
use Test::More;

use lib 'lib';
use Perbool::Command::FastaFilterComposition qw(base_fraction);

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

my ( $reverse_status, $reverse_output, $reverse_error ) = run_command(
    undef, 'bin/perbool', 'sequence', 'reverse-complement',
    'ACGTRYMKSWBDHVNUX',
);
is( $reverse_status, 0, 'normalized reverse-complement command exits successfully' );
is( $reverse_error,  '', 'normalized reverse-complement command emits no errors' );
is(
    $reverse_output,
    "XANBDHVWSMKRYACGT\n",
    'reverse complement supports RNA, X, and standard IUPAC ambiguity symbols',
);

my ( $reverse_stdin_status, $reverse_stdin_output, $reverse_stdin_error ) =
  run_command( "ACG\nU\n", $^X, 'rcdna.pl', '-' );
is( $reverse_stdin_status, 0, 'legacy reverse-complement entry accepts standard input' );
is( $reverse_stdin_error,  '', 'standard-input reverse complement emits no errors' );
is( $reverse_stdin_output, "ACGT\n", 'standard-input whitespace is ignored' );

my ( $bad_reverse_status, $bad_reverse_output, $bad_reverse_error ) =
  run_command( undef, $^X, 'rcdna.pl', 'AZ' );
isnt( $bad_reverse_status, 0, 'non-IUPAC sequence is rejected' );
is( $bad_reverse_output, '', 'invalid sequence produces no output' );
like( $bad_reverse_error, qr/non-IUPAC/, 'invalid sequence error is clear' );

my $reference_content = ">chr1 description\nAC\nGT\n>chr2\nuuNX\n";
my $reference_path = path_for('reference.fa');
my $reference_gzip_path = path_for('reference.fa.gz');
write_text( $reference_path, $reference_content );
write_gzip( $reference_gzip_path, $reference_content );

my $variants =
    "# independent variants\n"
  . "chr1 2 C T\n"
  . "chr1 2 CG AA\n"
  . "chr2 1 U A\n";
my $variant_path = path_for('variants.txt');
write_text( $variant_path, $variants );
my $expected_substitutions =
    ">chr1-2-C-T\nATGT\n"
  . ">chr1-2-CG-AA\nAAAT\n"
  . ">chr2-1-U-A\nAuNX\n";

my ( $substitute_status, $substitute_output, $substitute_error ) = run_command(
    undef, 'bin/perbool', 'fasta', 'substitute',
    '--fa', $reference_gzip_path, '--in', $variant_path,
);
is( $substitute_status, 0, 'normalized substitution command exits successfully' );
is( $substitute_error,  '', 'normalized substitution command emits no errors' );
is(
    $substitute_output,
    $expected_substitutions,
    'substitutions support gzip FASTA, multiline records, MNVs, and case-insensitive REF checks',
);

my ( $legacy_sub_status, $legacy_sub_output, $legacy_sub_error ) = run_command(
    "chr1 2 C T\n", $^X, 'snp4fasta.pl', '--fa', $reference_path, '--stdin',
);
is( $legacy_sub_status, 0, 'legacy substitution entry accepts variant standard input' );
is( $legacy_sub_error,  '', 'legacy substitution entry emits no errors' );
is( $legacy_sub_output, ">chr1-2-C-T\nATGT\n", 'legacy substitution output remains compatible' );

for my $invalid_variant (
    [ "chr1 0 A T\n", qr/positive integer/, 'zero position' ],
    [ "missing 1 A T\n", qr/Unknown FASTA ID/, 'unknown FASTA ID' ],
    [ "chr1 4 TT A\n", qr/beyond sequence length/, 'out-of-bounds REF' ],
    [ "chr1 1 T A\n", qr/Reference mismatch/, 'reference mismatch' ],
    [ "chr1 1 A A>bad\n", qr/only IUPAC/, 'invalid ALT characters' ],
    [ "chr1 1 A T extra\n", qr/expected ID POSITION REF ALT/, 'extra field' ],
) {
    my ( $status, $output, $error ) = run_command(
        $invalid_variant->[0], $^X, 'snp4fasta.pl',
        '--fa', $reference_path, '--stdin',
    );
    isnt( $status, 0, "$invalid_variant->[2] is rejected" );
    is( $output, '', "$invalid_variant->[2] produces no FASTA output" );
    like( $error, $invalid_variant->[1], "$invalid_variant->[2] error is clear" );
}

my ( $atomic_status, $atomic_output, $atomic_error ) = run_command(
    "chr1 2 C T\nchr1 1 T A\n", $^X, 'snp4fasta.pl',
    '--fa', $reference_path, '--stdin',
);
isnt( $atomic_status, 0, 'a later invalid variant fails the batch' );
is( $atomic_output, '', 'variant batch is validated before any output is emitted' );
like( $atomic_error, qr/Reference mismatch/, 'later batch error is reported clearly' );

is( base_fraction( 'NNXX', 'A' ), 0, 'ambiguity-only sequence has zero fraction' );
is( base_fraction( 'aCgTNN', 'A' ), 0.25, 'base fraction is case-insensitive' );

my $composition_content =
    ">high description\naa\nAN\n"
  . ">equal\nAACC\n"
  . ">low\nAGCC\n"
  . ">ambiguous\nNNXX\n";
my $composition_path = path_for('composition.fa');
my $composition_gzip_path = path_for('composition.fa.gz');
write_text( $composition_path, $composition_content );
write_gzip( $composition_gzip_path, $composition_content );

my ( $filter_status, $filter_output, $filter_error ) = run_command(
    undef, 'bin/perbool', 'fasta', 'filter-composition',
    '--base', 'a', '--fraction-above', '.5', '--in', $composition_gzip_path,
);
is( $filter_status, 0, 'normalized composition filter exits successfully' );
is( $filter_error,  '', 'normalized composition filter emits no errors' );
is(
    $filter_output,
    ">high description\naaAN\n",
    'composition filter handles gzip, multiline/lowercase sequence, ambiguity, and strict boundary',
);

my ( $legacy_filter_status, $legacy_filter_output, $legacy_filter_error ) =
  run_command( $composition_content, $^X, 'base_proportion.pl', 'A', '.5' );
is( $legacy_filter_status, 0, 'legacy composition filter syntax remains available' );
is( $legacy_filter_error,  '', 'legacy composition filter emits no errors' );
is( $legacy_filter_output, $filter_output, 'legacy and normalized filters agree' );

for my $invalid_filter (
    [ [ '--base', 'N', '--fraction-above', '.5' ], qr/one of A, C, G, or T/, 'invalid base' ],
    [ [ '--base', 'A', '--fraction-above', '1.1' ], qr/number from 0 to 1/, 'invalid fraction' ],
) {
    my ( $status, $output, $error ) = run_command(
        $composition_content, $^X, 'base_proportion.pl',
        @{ $invalid_filter->[0] },
    );
    isnt( $status, 0, "$invalid_filter->[2] is rejected" );
    is( $output, '', "$invalid_filter->[2] produces no output" );
    like( $error, $invalid_filter->[1], "$invalid_filter->[2] error is clear" );
}

done_testing();
