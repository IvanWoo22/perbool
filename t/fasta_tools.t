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
  fasta_id fasta_iterator open_fasta_reader sequence_text write_fasta_record
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
    if ( defined $input ) {
        print {$child_in} $input;
    }
    close $child_in;
    my $stdout_text = do { local $/; <$child_out> };
    my $stderr_text = do { local $/; <$stderr> };
    waitpid $pid, 0;
    return ( $?, $stdout_text, $stderr_text );
}

my $fasta_content =
    ">seq1 alpha\r\nAC\r\nGU\r\n\r\n"
  . ">seq2 literal[bracket]\nTT\n"
  . ">seq3\nACGU\n"
  . ">seq4 duplicate last\nAC\nGU\n";

open my $scalar_fh, '<', \$fasta_content;
my $next_record = fasta_iterator($scalar_fh);
my $first = $next_record->();
is( fasta_id($first), 'seq1', 'shared parser extracts the first FASTA ID' );
is( $first->{header}, '>seq1 alpha', 'shared parser preserves the description' );
is( sequence_text($first), 'ACGU', 'shared parser joins multiline sequences' );

my $canonical = '';
open my $scalar_out, '>', \$canonical;
write_fasta_record( $scalar_out, $first );
close $scalar_out;
is(
    $canonical,
    ">seq1 alpha\nACGU\n",
    'shared writer emits a canonical two-line FASTA record',
);

my @remaining;
while ( my $record = $next_record->() ) {
    push @remaining, fasta_id($record);
}
is_deeply(
    \@remaining,
    [qw(seq2 seq3 seq4)],
    'iterator returns every record in source order',
);

for my $invalid_case (
    [ "ACGT\n>seq1\nACGT\n", qr/before the first header/, 'sequence before header' ],
    [ ">\nACGT\n", qr/Invalid FASTA header/, 'header without an ID' ],
    [ ">empty\n>next\nACGT\n", qr/Empty FASTA sequence/, 'empty sequence' ],
) {
    open my $invalid_fh, '<', \$invalid_case->[0];
    my $invalid_next = fasta_iterator($invalid_fh);
    my $error = '';
    eval { $invalid_next->() };
    $error = $@;
    like( $error, $invalid_case->[1], "parser rejects $invalid_case->[2]" );
}

my $plain_path = path_for('input.fa');
my $gzip_path  = path_for('input.fa.gz');
write_text( $plain_path, $fasta_content );
write_gzip( $gzip_path, $fasta_content );

my $gzip_fh = open_fasta_reader($gzip_path);
my $gzip_next = fasta_iterator($gzip_fh);
is(
    sequence_text( $gzip_next->() ),
    'ACGU',
    'shared reader transparently reads gzip FASTA input',
);
close $gzip_fh;

my ( $fetch_status, $fetch_output, $fetch_error ) = run_command(
    undef, $^X, 'fetch_fasta.pl', '--fasta', $plain_path,
    '--string', '[bracket]',
);
is( $fetch_status, 0, 'FASTA title extraction exits successfully' );
is( $fetch_error,  '', 'FASTA title extraction emits no errors' );
is(
    $fetch_output,
    ">seq2 literal[bracket]\nTT\n",
    'title extraction treats search metacharacters literally',
);

my ( $exact_status, $exact_output, $exact_error ) = run_command(
    undef, $^X, 'fetch_fasta.pl', '--fasta', $plain_path,
    '--string', 'seq1', '--exact', '--rna2dna',
);
is( $exact_status, 0, 'exact FASTA extraction exits successfully' );
is( $exact_error,  '', 'exact FASTA extraction emits no errors' );
is(
    $exact_output,
    ">seq1 alpha\nACGT\n",
    'exact extraction matches the ID and converts RNA bases to DNA',
);

my ( $no_exact_status, $no_exact_output, $no_exact_error ) = run_command(
    undef, $^X, 'fetch_fasta.pl', '--fasta', $plain_path,
    '--string', 'seq', '--exact',
);
is( $no_exact_status, 0, 'an exact search with no match is successful' );
is( $no_exact_output, '', 'exact matching does not accept partial IDs' );
is( $no_exact_error,  '', 'an exact search with no match emits no errors' );

my ( $stdin_status, $stdin_output, $stdin_error ) = run_command(
    $fasta_content, $^X, 'fetch_fasta.pl', '--stdin',
    '--string', 'seq3', '--exact',
);
is( $stdin_status, 0, 'FASTA extraction accepts standard input' );
is( $stdin_error,  '', 'standard-input extraction emits no errors' );
is( $stdin_output, ">seq3\nACGU\n", 'standard-input extraction is correct' );

my ( $gzip_status, $gzip_output, $gzip_error ) = run_command(
    undef, $^X, 'fetch_fasta.pl', '--fasta', $gzip_path,
    '--string', 'seq2', '--exact',
);
is( $gzip_status, 0, 'FASTA extraction accepts gzip input' );
is( $gzip_error,  '', 'gzip FASTA extraction emits no errors' );
is( $gzip_output, ">seq2 literal[bracket]\nTT\n", 'gzip extraction is correct' );

my ( $unique_status, $unique_output, $unique_error ) =
  run_command( undef, $^X, 'unique_fasta.pl', $plain_path );
is( $unique_status, 0, 'FASTA deduplication exits successfully' );
is( $unique_error,  '', 'FASTA deduplication emits no errors' );
is(
    $unique_output,
    ">seq1 alpha\nACGU\n>seq2 literal[bracket]\nTT\n",
    'deduplication keeps the first occurrence and removes a duplicate final record',
);

my ( $unique_gzip_status, $unique_gzip_output, $unique_gzip_error ) =
  run_command( undef, $^X, 'unique_fasta.pl', $gzip_path );
is( $unique_gzip_status, 0, 'FASTA deduplication accepts gzip input' );
is( $unique_gzip_error,  '', 'gzip deduplication emits no errors' );
is( $unique_gzip_output, $unique_output, 'gzip and plain deduplication agree' );

my $invalid_path = path_for('invalid.fa');
write_text( $invalid_path, "not-a-header\nACGT\n" );
my ( $invalid_status, undef, $invalid_error ) =
  run_command( undef, $^X, 'unique_fasta.pl', $invalid_path );
isnt( $invalid_status, 0, 'FASTA deduplication rejects malformed input' );
like(
    $invalid_error,
    qr/before the first header/,
    'FASTA deduplication reports malformed input clearly',
);

my ( $argument_status, undef, $argument_error ) =
  run_command( undef, $^X, 'fetch_fasta.pl', '--fasta', $plain_path );
isnt( $argument_status, 0, 'FASTA extraction requires a search string' );
like( $argument_error, qr/--string is required/, 'missing search string is clear' );

done_testing();
