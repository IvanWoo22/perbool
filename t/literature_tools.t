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

my $fake_backend = path_for('fake_pubmed_backend.pl');
my $fake_source = <<'FAKE';
#!/usr/bin/env perl
use strict;
use warnings;
shift @ARGV if @ARGV == 6;
my ( $query, $output, $min_year, $max_year, $retmax ) = @ARGV;
die "wrong argument count\n" unless @ARGV == 5;
exit 23 if $query eq 'FAIL';
open my $fh, '>', $output or die "Cannot write $output: $!";
print {$fh} qq{"Title","PMID","Range"\n};
print {$fh} qq{"$query title","123","$min_year-$max_year/$retmax"};
close $fh;
FAKE
write_text( $fake_backend, $fake_source );

my $marker_path = path_for('shell-injection-marker');
my $unsafe_query = "unsafe;touch $marker_path";
my $queries = "alpha cancer\n\n$unsafe_query\n";
my $queries_gzip = path_for('queries.txt.gz');
my $output_gzip = path_for('pubmed-results.txt.gz');
write_gzip( $queries_gzip, $queries );

my ( $status, $output, $error ) = run_command(
    undef, 'bin/perbool', 'literature', 'pubmed-search',
    '--queries', $queries_gzip, '--out', $output_gzip,
    '--work-dir', $tempdir, '--rscript', $^X, '--r-script', $fake_backend,
    '--min-year', 2018, '--max-year', 2024, '--retmax', 7,
);
is( $status, 0, 'normalized PubMed search exits successfully' );
is( $output, '', 'file-output PubMed search emits no standard output' );
is( $error, '', 'normalized PubMed search emits no errors' );
my $expected =
    "alpha cancer\n"
  . "\"Title\",\"PMID\",\"Range\"\n"
  . "\"alpha cancer title\",\"123\",\"2018-2024/7\"\n\n"
  . "$unsafe_query\n"
  . "\"Title\",\"PMID\",\"Range\"\n"
  . "\"$unsafe_query title\",\"123\",\"2018-2024/7\"\n\n";
is(
    read_gzip($output_gzip),
    $expected,
    'queries, CSV blocks, separators, parameters, and gzip output are correct',
);
ok( !-e $marker_path, 'query text is never interpreted by a shell' );

my ( $stdout_status, $stdout_output, $stdout_error ) = run_command(
    "one query\n", 'bin/perbool', 'literature', 'pubmed-search',
    '--queries', '-', '--rscript', $^X, '--r-script', $fake_backend,
    '--min-year', 2020, '--max-year', 2021, '--retmax', 1,
);
is( $stdout_status, 0, 'PubMed queries can be read from standard input' );
is( $stdout_error, '', 'standard-input PubMed search emits no errors' );
is(
    $stdout_output,
    "one query\n\"Title\",\"PMID\",\"Range\"\n"
      . "\"one query title\",\"123\",\"2020-2021/1\"\n\n",
    'standard output uses the documented historical framing',
);

my $fake_rscript = path_for('Rscript');
write_text( $fake_rscript, $fake_source );
chmod 0755, $fake_rscript or die "Cannot make fake Rscript executable: $!";
my $legacy_queries = path_for('legacy-queries.txt');
my $legacy_output = path_for('legacy-results.txt');
write_text( $legacy_queries, "legacy query\n" );
my $current_year = ( localtime )[5] + 1900;
my ( $legacy_status, $legacy_stdout, $legacy_error );
{
    local $ENV{PATH} = "$tempdir:$ENV{PATH}";
    ( $legacy_status, $legacy_stdout, $legacy_error ) = run_command(
        undef, $^X, 'extract_pubmed_info.pl',
        $legacy_queries, $tempdir, $legacy_output,
    );
}
is( $legacy_status, 0, 'legacy three-argument PubMed syntax remains available' );
is( $legacy_stdout, '', 'legacy file output emits no standard output' );
is( $legacy_error, '', 'legacy PubMed syntax emits no errors' );
is(
    read_text($legacy_output),
    "legacy query\n\"Title\",\"PMID\",\"Range\"\n"
      . "\"legacy query title\",\"123\",\"2010-$current_year/100\"\n\n",
    'legacy syntax delegates to the current default search range',
);

my $failure_queries = path_for('failure-queries.txt');
my $preserved_output = path_for('preserved-results.txt');
write_text( $failure_queries, "first succeeds\nFAIL\n" );
write_text( $preserved_output, "existing output\n" );
my ( $failure_status, $failure_output, $failure_error ) = run_command(
    undef, 'bin/perbool', 'literature', 'pubmed-search',
    '--queries', $failure_queries, '--out', $preserved_output,
    '--rscript', $^X, '--r-script', $fake_backend,
);
isnt( $failure_status, 0, 'a failed R query is reported' );
is( $failure_output, '', 'failed batch produces no standard output' );
like( $failure_error, qr/exit code 23/, 'failed R query includes its exit code' );
is(
    read_text($preserved_output),
    "existing output\n",
    'failed batch does not replace an existing output file',
);

for my $invalid (
    [ [ '--min-year', 2025, '--max-year', 2024 ], qr/must not exceed/, 'reversed year range' ],
    [ [ '--retmax', 0 ], qr/positive integer/, 'zero result limit' ],
) {
    my ( $bad_status, $bad_output, $bad_error ) = run_command(
        undef, 'bin/perbool', 'literature', 'pubmed-search',
        '--queries', $legacy_queries, '--rscript', $^X,
        '--r-script', $fake_backend, @{ $invalid->[0] },
    );
    isnt( $bad_status, 0, "$invalid->[2] is rejected" );
    is( $bad_output, '', "$invalid->[2] produces no output" );
    like( $bad_error, $invalid->[1], "$invalid->[2] error is clear" );
}

my $empty_queries = path_for('empty-queries.txt');
write_text( $empty_queries, "\n \n" );
my ( $empty_status, $empty_output, $empty_error ) = run_command(
    undef, 'bin/perbool', 'literature', 'pubmed-search',
    '--queries', $empty_queries, '--rscript', $^X, '--r-script', $fake_backend,
);
isnt( $empty_status, 0, 'empty query list is rejected' );
is( $empty_output, '', 'empty query list produces no output' );
like( $empty_error, qr/no nonblank queries/, 'empty query-list error is clear' );

my ( $same_status, $same_output, $same_error ) = run_command(
    undef, 'bin/perbool', 'literature', 'pubmed-search',
    '--queries', $legacy_queries, '--out', $legacy_queries,
    '--rscript', $^X, '--r-script', $fake_backend,
);
isnt( $same_status, 0, 'identical query and output paths are rejected' );
is( $same_output, '', 'identical path rejection produces no output' );
like( $same_error, qr/different files/, 'identical path error is clear' );

done_testing();
