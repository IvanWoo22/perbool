package Perbool::StagedOutput;

use strict;
use warnings;
use autodie;

use Exporter qw(import);
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempdir);

our @EXPORT_OK = qw(commit_output_group create_output_group);

sub create_output_group {
    my @final_paths = @_;
    die "At least one output path is required\n" unless @final_paths;
    die "Standard output cannot be used in a staged output group\n"
      if grep { $_ eq '-' } @final_paths;

    my $output_directory = dirname( $final_paths[0] );
    die "Output directory does not exist: $output_directory\n"
      unless -d $output_directory;
    for my $path (@final_paths) {
        die "All staged outputs must use the same directory\n"
          unless dirname($path) eq $output_directory;
        die "Output path is a directory: $path\n" if -d $path;
    }

    my $staging_directory = tempdir(
        '.perbool-output-XXXXXX',
        DIR     => $output_directory,
        CLEANUP => 1,
    );
    my @staged_paths;
    for my $index ( 0 .. $#final_paths ) {
        my $suffix = $final_paths[$index] =~ /[.]gz\z/i ? '.gz' : '';
        push @staged_paths,
          File::Spec->catfile(
            $staging_directory, sprintf( 'output-%03d%s', $index + 1, $suffix ),
          );
    }
    return {
        final  => \@final_paths,
        staged => \@staged_paths,
    };
}

sub commit_output_group {
    my $group = shift;
    die "Invalid staged output group\n"
      unless ref $group eq 'HASH'
      && ref $group->{final} eq 'ARRAY'
      && ref $group->{staged} eq 'ARRAY'
      && @{ $group->{final} } == @{ $group->{staged} };
    for my $path ( @{ $group->{staged} } ) {
        die "Staged output is missing: $path\n" unless -f $path;
    }
    for my $index ( 0 .. $#{ $group->{final} } ) {
        rename $group->{staged}[$index], $group->{final}[$index];
    }
    return;
}

1;
