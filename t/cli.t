use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use IPC::Open3;
use Symbol qw(gensym);
use Test::More;

use lib 'lib';
use Perbool::CLI qw(command_rows);

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

my @rows = command_rows();
is( scalar @rows, 31, 'normalized CLI exposes the maintained command set' );
ok( -x 'bin/perbool', 'normalized CLI entry point is executable' );
my %command_name;
for my $row (@rows) {
    like( $row->[0], qr/\A[a-z][a-z0-9-]*\z/, 'group name is normalized' );
    like( $row->[1], qr/\A[a-z][a-z0-9-]*\z/, 'command name is normalized' );
    ok( !$command_name{ "$row->[0] $row->[1]" }++, 'group-command pair is unique' );
    ok( -f $row->[2], 'mapped implementation exists' );
}

my ( $help_status, $help_output, $help_error ) =
  run_command( undef, 'bin/perbool', '--help' );
is( $help_status, 0, 'top-level CLI help exits successfully' );
is( $help_error,  '', 'top-level CLI help emits no errors' );
like( $help_output, qr/^Usage: perbool GROUP COMMAND/m, 'help shows usage' );
like( $help_output, qr/^  fasta$/m, 'help groups FASTA commands' );
like( $help_output, qr/^  sequence$/m, 'help groups sequence commands' );
like( $help_output, qr/^  table$/m, 'help groups table commands' );
like( $help_output, qr/^  genome$/m, 'help groups genome commands' );
like( $help_output, qr/^  small-rna$/m, 'help groups small-RNA commands' );
like( $help_output, qr/^  literature$/m, 'help groups literature commands' );
like( $help_output, qr/^  fastq$/m, 'help groups FASTQ commands' );
like( $help_output, qr/^  qc$/m, 'help groups QC commands' );

my ( $unknown_status, $unknown_output, $unknown_error ) =
  run_command( undef, 'bin/perbool', 'fasta', 'not-a-command' );
isnt( $unknown_status, 0, 'unknown normalized command is rejected' );
is( $unknown_output, '', 'unknown command produces no standard output' );
like( $unknown_error, qr/Unknown perbool command/, 'unknown command error is clear' );

my $fasta_path = path_for('input.fa');
my $names_path = path_for('names.txt');
my $deleted_path = path_for('deleted.fa');
write_text( $fasta_path, ">one\nAA\n>two\nCC\n" );
write_text( $names_path, "one\n" );
is(
    system(
        'bin/perbool', 'fasta', 'delete', '--name', $names_path,
        '--in', $fasta_path, '--out', $deleted_path,
    ),
    0,
    'normalized FASTA deletion dispatches successfully',
);
is( read_text($deleted_path), ">two\nCC\n", 'normalized FASTA deletion is correct' );

my ( $fastq_status, $fastq_output, $fastq_error ) = run_command(
    "\@read description\nAC\n+\nII\n",
    'bin/perbool', 'fastq', 'to-fasta',
);
is( $fastq_status, 0, 'normalized FASTQ conversion dispatches successfully' );
is( $fastq_error,  '', 'normalized FASTQ conversion emits no errors' );
is( $fastq_output, ">read description\nAC\n", 'normalized FASTQ conversion is correct' );

done_testing();
