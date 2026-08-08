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

my $fasta_content =
    ">one description\nAA\nAA\n"
  . ">one_more\nTT\n"
  . ">two\nCC\n"
  . ">three[1] final\nGG\nGG\n";
my $input_path = path_for('input.fa');
my $names_path = path_for('names.txt');
my $output_path = path_for('output.fa');
write_text( $input_path, $fasta_content );
write_text( $names_path, ">one description\none\nthree[1]\n\n" );

is(
    system(
        $^X, 'delete_fasta.pl', '--name', $names_path,
        '--in', $input_path, '--out', $output_path,
    ),
    0,
    'direct FASTA deletion exits successfully',
);
is(
    read_text($output_path),
    ">one_more\nTT\n>two\nCC\n",
    'direct deletion matches complete IDs and preserves non-target order',
);

isnt(
    system(
        $^X, 'delete_fasta.pl', '--name', $names_path,
        '--in', $input_path, '--out', $input_path,
    ),
    0,
    'direct deletion rejects identical input and output paths',
);
is( read_text($input_path), $fasta_content, 'same-path rejection preserves input' );

SKIP: {
    my $hardlink_path = path_for('input-hardlink.fa');
    skip 'hard links are unavailable on this filesystem', 2
      unless link $input_path, $hardlink_path;
    isnt(
        system(
            $^X, 'delete_fasta.pl', '--name', $names_path,
            '--in', $input_path, '--out', $hardlink_path,
        ),
        0,
        'direct deletion rejects a hard-linked output path',
    );
    is( read_text($input_path), $fasta_content, 'hard-link rejection preserves input' );
}

my $gzip_input = path_for('input.fa.gz');
my $gzip_output = path_for('output.fa.gz');
write_gzip( $gzip_input, $fasta_content );
is(
    system(
        $^X, 'delete_fasta.pl', '--name', $names_path,
        '--in', $gzip_input, '--out', $gzip_output,
    ),
    0,
    'direct deletion supports gzip input and output',
);
is( read_gzip($gzip_output), read_text($output_path), 'gzip deletion matches plain output' );

my ( $range_status, $range_output, $range_error ) =
  run_command( undef, $^X, 'delete_fasta_1.pl', $input_path, $names_path );
is( $range_status, 0, 'legacy range discovery exits successfully' );
is( $range_error,  '', 'legacy range discovery emits no errors' );
is(
    $range_output,
    "0\t3\n7\t3\n",
    'legacy discovery is idempotent, literal, and includes the final sequence line',
);

my $ranges_path = path_for('ranges.tsv');
write_text( $ranges_path, $range_output );
my ( $legacy_status, $legacy_output, $legacy_error ) =
  run_command( undef, $^X, 'delete_fasta_2.pl', $input_path, $ranges_path );
is( $legacy_status, 0, 'legacy deletion exits successfully' );
is( $legacy_error,  '', 'legacy deletion emits no errors' );
is(
    $legacy_output,
    ">one_more\nTT\n>two\nCC\n",
    'descending legacy deletion avoids index-shift corruption',
);

my $overlap_path = path_for('overlap.tsv');
write_text( $overlap_path, "0\t3\n2\t2\n" );
my ( $overlap_status, undef, $overlap_error ) =
  run_command( undef, $^X, 'delete_fasta_2.pl', $input_path, $overlap_path );
isnt( $overlap_status, 0, 'overlapping legacy deletion ranges are rejected' );
like( $overlap_error, qr/Overlapping deletion ranges/, 'overlap error is clear' );

my $table_content = "r1|ACGU\nr2|TT\nr3|ACGU\n";
my $table_path = path_for('sequences.txt');
write_text( $table_path, $table_content );
my $expected_list_fasta =
  ">seq1 LENGTH=4 REPEAT=2\nACGT\n>seq2 LENGTH=2 REPEAT=1\nTT\n";
my ( $list_status, $list_output, $list_error ) = run_command(
    undef, $^X, 'list2fasta.pl', '--file', $table_path,
    '--sep', '|', '--col', 2, '--rna2dna',
);
is( $list_status, 0, 'table-to-FASTA conversion exits successfully' );
is( $list_error,  '', 'table-to-FASTA conversion emits no errors' );
is(
    $list_output,
    $expected_list_fasta,
    'literal separator, newline trimming, counts, lengths, and order are correct',
);

my ( $list_stdin_status, $list_stdin_output, $list_stdin_error ) = run_command(
    $table_content, $^X, 'list2fasta.pl', '--stdin',
    '--sep', '|', '--col', 2, '--rna2dna',
);
is( $list_stdin_status, 0, 'table-to-FASTA conversion accepts standard input' );
is( $list_stdin_error,  '', 'standard-input conversion emits no errors' );
is( $list_stdin_output, $expected_list_fasta, 'file and standard input agree' );

my ( $missing_status, $missing_output, $missing_error ) = run_command(
    "only-one-column\n", $^X, 'list2fasta.pl', '--stdin', '--col', 2,
);
isnt( $missing_status, 0, 'missing sequence column is rejected' );
is( $missing_output, '', 'missing sequence column produces no FASTA output' );
like( $missing_error, qr/Missing column 2/, 'missing column error includes context' );

my ( $column_status, undef, $column_error ) =
  run_command( '', $^X, 'list2fasta.pl', '--stdin', '--col', 0 );
isnt( $column_status, 0, 'zero sequence column is rejected' );
like( $column_error, qr/--col must be a positive integer/, 'column error is clear' );

done_testing();
