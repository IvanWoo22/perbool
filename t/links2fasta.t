use strict;
use warnings;

use File::Temp qw(tempfile);
use Test::More tests => 2;

my ( $fa_fh, $fa_path ) = tempfile();
print {$fa_fh} ">chr1\nACGTACGT\n>chr2\nAAACCC\n";
close $fa_fh;

my ( $list_fh, $list_path ) = tempfile();
print {$list_fh} "chr1:2-5\nsample.chr2(-):1-3\n";
close $list_fh;

open my $result_fh, '-|', $^X, 'links2fasta.pl',
  '--fa', $fa_path, '--in', $list_path;
my $output = do { local $/; <$result_fh> };
close $result_fh;

is( $?, 0, 'links2fasta exits successfully' );
is(
    $output,
    ">chr1:2-5\nCGTA\n>sample.chr2(-):1-3\nTTT\n",
    'extracts positive and reverse-complemented negative strand sequences',
);
